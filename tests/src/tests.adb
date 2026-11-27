
--  Unit tests. Plain Ada, no framework, non-zero exit on failure.
--  Covers record format, CRC, log recovery, crash injection and store API.
with Reference_Model;
with Ada.Command_Line;
with Ada.Text_IO;           use Ada.Text_IO;
with Legder;                use Legder;
with Legder.Record_Format;  use Legder.Record_Format;
with Legder.RAM_Device;
with Legder.Log;
with Legder.Store;

procedure Tests is

   package Dev renames Legder.RAM_Device;
   package L  is new Legder.Log
     (Dev.Block_Count, Dev.Read, Dev.Write, Dev.Sync);
   package KV is new Legder.Store
     (Dev.Block_Count, Dev.Read, Dev.Write, Dev.Sync);

   Failures : Natural := 0;

   procedure Check (Name : String; Cond : Boolean) is
   begin
      Put_Line ((if Cond then "PASS  " else "FAIL  ") & Name);
      if not Cond then
         Failures := Failures + 1;
      end if;
   end Check;

   function K (S : String) return Key is
      R : Key;
   begin
      R.Length := S'Length;
      for I in S'Range loop
         R.Bytes (I - S'First + 1) :=
           Byte (Character'Pos (S (I)));
      end loop;
      return R;
   end K;

   function V (S : String) return Value is
      R : Value;
   begin
      R.Length := S'Length;
      for I in S'Range loop
         R.Bytes (I - S'First + 1) :=
           Byte (Character'Pos (S (I)));
      end loop;
      return R;
   end V;

   ---------------------------------------------------------------------

   procedure Test_CRC is
      Empty : constant Byte_Array (1 .. 0) := [];
      Check_Str : constant Byte_Array (1 .. 9) :=
        [16#31#, 16#32#, 16#33#, 16#34#, 16#35#,
         16#36#, 16#37#, 16#38#, 16#39#];
   begin
      Check ("CRC empty", CRC (Empty) = 0);
      Check ("CRC '123456789' = CBF43926",
             CRC (Check_Str) = 16#CBF43926#);
   end Test_CRC;

   ---------------------------------------------------------------------

   procedure Test_Record is
      R, D  : Log_Record;
      B     : Block;
      Valid : Boolean;
   begin
      R := (Seq => 42, Kind => Put, K => K ("key"), V => V ("value"));
      Encode (R, B);
      Decode (B, D, Valid);
      Check ("round trip equivalent",
      Valid and then Equivalent (R, D));

      Check ("round trip valid", Valid);
      Check ("round trip seq", D.Seq = 42);
      Check ("round trip kind", D.Kind = Put);
      Check ("round trip key", D.K = K ("key"));
      Check ("round trip value", Same (D.V, V ("value")));

      B (100) := B (100) xor 1;
      Decode (B, D, Valid);
      Check ("bit flip rejected", not Valid);

      B := [others => 16#FF#];
      Decode (B, D, Valid);
      Check ("erased block rejected", not Valid);

      B := [others => 0];
      Decode (B, D, Valid);
      Check ("zero block rejected", not Valid);

      R := (Seq => 1, Kind => Delete,
            K => K ("gone"), V => V ("ignored"));
      Encode (R, B);
      Decode (B, D, Valid);

      Check ("delete round trip",
             Valid and then D.Kind = Delete
             and then D.K = K ("gone"));
      Check ("delete carries no value", D.V.Length = 0);
   end Test_Record;

   ---------------------------------------------------------------------

   procedure Test_Log is
      S    : L.State;
      N    : Natural;
      OK   : Boolean;
      Seen : Natural := 0;

      procedure Visit (R : Log_Record) is
      begin
         Seen := Seen + 1;
         if Seen = 2 then
            Check ("scan order: second is b", R.K = K ("b"));
         end if;
      end Visit;

      procedure Scan is new L.Scan (Visit);

   begin
      Dev.Erase;
      L.Open (S, N);
      Check ("empty log opens with 0", N = 0 and S.Head = 0);

      L.Append (S, Put, K ("a"), V ("1"), OK);
      L.Append (S, Put, K ("b"), V ("2"), OK);
      L.Append (S, Put, K ("c"), V ("3"), OK);

      Check ("three appends",
             OK and S.Head = 3 and S.Last_Seq = 3);
      Check ("one sync per append", Dev.Syncs = 3);

      L.Open (S, N);
      Check ("reopen finds 3",
             N = 3 and S.Head = 3 and S.Last_Seq = 3);

      Scan (S);
      Check ("scan visits 3", Seen = 3);

      -- Test torn write recovery.
      Dev.Tear_Next_Write;
      L.Append (S, Put, K ("d"), V ("4"), OK);
      L.Open (S, N);

      Check ("torn record not recovered",
             N = 3 and S.Head = 3);

      L.Append (S, Put, K ("e"), V ("5"), OK);
      L.Open (S, N);

      Check ("append after torn overwrites it",
             N = 4 and S.Last_Seq = 4);

      -- Test stale valid record with wrong sequence.
      declare
         B : Block;
         R : constant Log_Record :=
           (Seq => 99, Kind => Put,
            K => K ("stale"), V => V ("x"));
      begin
         Encode (R, B);
         Dev.Write (4, B);
         Dev.Sync;
      end;

      L.Open (S, N);
      Check ("stale valid block with wrong seq stops recovery",
             N = 4);
      -- Clear stale block before testing unsynced write.
      declare
         B : constant Block := [others => 16#FF#];
      begin
         Dev.Write (4, B);
         Dev.Sync;
      end;

      

      -- Simulate crash before Sync.
      declare
         B : Block;
         R : constant Log_Record :=
           (Seq => 5, Kind => Put,
            K => K ("unsynced"), V => V ("6"));
      begin
         Encode (R, B);
         Dev.Write (4, B);
         Dev.Drop_Unsynced;
      end;

      L.Open (S, N);
      Check ("unsynced write is not recovered",
             N = 4 and S.Head = 4 and S.Last_Seq = 4);

   end Test_Log;

   ---------------------------------------------------------------------

   procedure Test_Store is
      N     : Natural;
      OK    : Boolean;
      Got   : Value;
      Found : Boolean;
   begin
      Dev.Erase;

      declare
         S : KV.Store;
      begin
         KV.Open (S, N);

         KV.Put (S, K ("x"), V ("1"), OK);
         KV.Put (S, K ("y"), V ("2"), OK);
         KV.Put (S, K ("x"), V ("3"), OK);

         Check ("count after overwrite", KV.Count (S) = 2);

         KV.Delete (S, K ("y"), OK);
         Check ("count after delete", KV.Count (S) = 1);

         KV.Get (S, K ("x"), Got, Found);
         Check ("get latest",
                Found and then Same (Got, V ("3")));

         KV.Get (S, K ("y"), Got, Found);
         Check ("get deleted", not Found);
      end;

      declare
         S : KV.Store;
      begin
         KV.Open (S, N);

         Check ("replayed 4", N = 4);

         KV.Get (S, K ("x"), Got, Found);
         Check ("survives reopen",
                Found and then Same (Got, V ("3")));

         Check ("count after reopen", KV.Count (S) = 1);
      end;
   end Test_Store;

   ---------------------------------------------------------------------
   procedure Test_Binary_Search is
      N     : Natural;
      OK    : Boolean;
      Got   : Value;
      Found : Boolean;
      S     : KV.Store;
   begin
      Dev.Erase;
      KV.Open (S, N);

      -- Insert keys in unsorted order.
      KV.Put (S, K ("z"), V ("26"), OK);
      KV.Put (S, K ("a"), V ("1"), OK);
      KV.Put (S, K ("m"), V ("13"), OK);
      KV.Put (S, K ("c"), V ("3"), OK);
      KV.Put (S, K ("x"), V ("24"), OK);

      Check ("binary search count", KV.Count (S) = 5);

      -- Search for keys.
      KV.Get (S, K ("a"), Got, Found);
      Check ("binary search first key",
             Found and then Same (Got, V ("1")));

      KV.Get (S, K ("m"), Got, Found);
      Check ("binary search middle key",
             Found and then Same (Got, V ("13")));

      KV.Get (S, K ("z"), Got, Found);
      Check ("binary search last key",
             Found and then Same (Got, V ("26")));

      -- Update an existing key.
      KV.Put (S, K ("m"), V ("updated"), OK);
      KV.Get (S, K ("m"), Got, Found);
      Check ("binary search updated key",
             Found and then Same (Got, V ("updated")));

      -- Delete a key.
      KV.Delete (S, K ("c"), OK);
      KV.Get (S, K ("c"), Got, Found);
      Check ("binary search deleted key", not Found);

      -- Other keys must remain searchable.
      KV.Get (S, K ("x"), Got, Found);
      Check ("binary search after deletion",
             Found and then Same (Got, V ("24")));

      Check ("binary search count after deletion",
             KV.Count (S) = 4);

   end Test_Binary_Search;
   procedure Test_Deletion_Edge_Cases is
      N     : Natural;
      OK    : Boolean;
      Got   : Value;
      Found : Boolean;
      S     : KV.Store;
   begin
      Dev.Erase;
      KV.Open (S, N);

      KV.Put (S, K ("b"), V ("2"), OK);
      KV.Put (S, K ("a"), V ("1"), OK);
      KV.Put (S, K ("c"), V ("3"), OK);

      -- Delete first key.
      KV.Delete (S, K ("a"), OK);
      KV.Get (S, K ("a"), Got, Found);
      Check ("delete first key", not Found);

      KV.Get (S, K ("b"), Got, Found);
      Check ("search after deleting first key",
             Found and then Same (Got, V ("2")));

      -- Delete last key.
      KV.Delete (S, K ("c"), OK);
      KV.Get (S, K ("c"), Got, Found);
      Check ("delete last key", not Found);

      -- Delete only remaining key.
      KV.Delete (S, K ("b"), OK);
      Check ("delete only remaining key", KV.Count (S) = 0);

      KV.Get (S, K ("b"), Got, Found);
      Check ("search empty store", not Found);

      -- Insert again after all deletions.
      KV.Put (S, K ("d"), V ("4"), OK);
      KV.Get (S, K ("d"), Got, Found);
      Check ("insert after deleting all",
             OK and then Found and then Same (Got, V ("4")));

   end Test_Deletion_Edge_Cases;
   procedure Test_Reference_Model is
      N           : Natural;
      Store_OK    : Boolean;
      Model_OK    : Boolean;
      Store_Found : Boolean;
      Model_Found : Boolean;
      Store_Value : Value;
      Model_Value : Value;

      S : KV.Store;
      M : Reference_Model.Model;
   begin
      Dev.Erase;
      KV.Open (S, N);
      Reference_Model.Clear (M);

      -- Insert records
      Reference_Model.Put (M, K ("z"), V ("26"), Model_OK);
      KV.Put (S, K ("z"), V ("26"), Store_OK);
      Check ("reference model insert z",
             Model_OK and Store_OK);

      Reference_Model.Put (M, K ("a"), V ("1"), Model_OK);
      KV.Put (S, K ("a"), V ("1"), Store_OK);
      Check ("reference model insert a",
             Model_OK and Store_OK);

      -- Update an existing record
      Reference_Model.Put (M, K ("a"), V ("updated"), Model_OK);
      KV.Put (S, K ("a"), V ("updated"), Store_OK);
      Check ("reference model update",
             Model_OK and Store_OK);

      -- Delete a record
      Reference_Model.Delete (M, K ("z"));
      KV.Delete (S, K ("z"), Store_OK);
      Check ("reference model delete", Store_OK);

      -- Compare results
      Reference_Model.Get (M, K ("a"), Model_Value, Model_Found);
      KV.Get (S, K ("a"), Store_Value, Store_Found);

      Check ("reference model get",
             Model_Found = Store_Found
             and then Model_Found
             and then Same (Model_Value, Store_Value));

      Reference_Model.Get (M, K ("z"), Model_Value, Model_Found);
      KV.Get (S, K ("z"), Store_Value, Store_Found);

      Check ("reference model deleted key",
             Model_Found = Store_Found
             and then not Model_Found);

      Check ("reference model count",
             Reference_Model.Count (M) = KV.Count (S));

   end Test_Reference_Model;

   procedure Test_Capacity is
      N             : Natural;
      OK            : Boolean;
      S             : KV.Store;
      Writes_Before : Natural;
   begin
      Dev.Erase;
      KV.Open (S, N);

      for I in 1 .. KV.Max_Entries loop
         KV.Put (S, K ("k" & I'Image), V ("v"), OK);
         exit when not OK;
      end loop;
      Check ("store reached capacity",
             KV.Count (S) = KV.Max_Entries);

      Writes_Before := Dev.Writes;

      KV.Put (S, K ("one more"), V ("v"), OK);

      Check ("put on full store fails cleanly", not OK);
      Check ("no write on refused put",
             Dev.Writes = Writes_Before);
   end Test_Capacity;

begin
   Test_CRC;
   Test_Record;
   Test_Log;
   Test_Store;
   Test_Binary_Search;
   Test_Deletion_Edge_Cases;
   Test_Reference_Model;
   Test_Capacity;
   New_Line;

   if Failures = 0 then
      Put_Line ("all tests passed");
   else
      Put_Line (Failures'Image & " failure(s)");
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Failure);
   end if;

end Tests;


--  Unit tests. Plain Ada, no framework, non-zero exit on failure.
--  Covers the record format round trip, CRC vectors, log recovery
--  under the device's fault injection, and the store API.

with Ada.Command_Line;
with Ada.Text_IO;           use Ada.Text_IO;
with Legder;                use Legder;
with Legder.Record_Format;  use Legder.Record_Format;
with Legder.RAM_Device;
with Legder.Log;
with Legder.Store;

procedure Tests is

   package Dev renames Legder.RAM_Device;
   package L  is new Legder.Log   (Dev.Block_Count, Dev.Read, Dev.Write, Dev.Sync);
   package KV is new Legder.Store (Dev.Block_Count, Dev.Read, Dev.Write, Dev.Sync);

   Failures : Natural := 0;

   procedure Check (Name : String; Cond : Boolean) is
   begin
      Put_Line ((if Cond then "PASS  " else "FAIL  ") & Name);
      if not Cond then Failures := Failures + 1; end if;
   end Check;

   function K (S : String) return Key is
      R : Key;
   begin
      R.Length := S'Length;
      for I in S'Range loop R.Bytes (I - S'First + 1) := Byte (Character'Pos (S (I))); end loop;
      return R;
   end K;

   function V (S : String) return Value is
      R : Value;
   begin
      R.Length := S'Length;
      for I in S'Range loop R.Bytes (I - S'First + 1) := Byte (Character'Pos (S (I))); end loop;
      return R;
   end V;

   ---------------------------------------------------------------------

   procedure Test_CRC is
      Empty : constant Byte_Array (1 .. 0) := [];
      Check_Str : constant Byte_Array (1 .. 9) :=
        [16#31#, 16#32#, 16#33#, 16#34#, 16#35#, 16#36#, 16#37#, 16#38#, 16#39#];  --  "123456789"
   begin
      Check ("CRC empty", CRC (Empty) = 0);
      Check ("CRC '123456789' = CBF43926", CRC (Check_Str) = 16#CBF43926#);
   end Test_CRC;

   procedure Test_Record is
      R, D  : Log_Record;
      B     : Block;
      Valid : Boolean;
   begin
      R := (Seq => 42, Kind => Put, K => K ("key"), V => V ("value"));
      Encode (R, B);
      Decode (B, D, Valid);
      Check ("round trip valid", Valid);
      Check ("round trip seq",   D.Seq = 42);
      Check ("round trip kind",  D.Kind = Put);
      Check ("round trip key",   D.K = K ("key"));
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

      R := (Seq => 1, Kind => Delete, K => K ("gone"), V => V ("ignored"));
      Encode (R, B);
      Decode (B, D, Valid);
      Check ("delete round trip", Valid and then D.Kind = Delete and then D.K = K ("gone"));
      Check ("delete carries no value", D.V.Length = 0);
   end Test_Record;

   procedure Test_Log is
      S  : L.State;
      N  : Natural;
      OK : Boolean;
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
      Check ("three appends", OK and S.Head = 3 and S.Last_Seq = 3);
      Check ("one sync per append", Dev.Syncs = 3);

      L.Open (S, N);
      Check ("reopen finds 3", N = 3 and S.Head = 3 and S.Last_Seq = 3);
      Scan (S);
      Check ("scan visits 3", Seen = 3);

      Dev.Tear_Next_Write;
      L.Append (S, Put, K ("d"), V ("4"), OK);
      L.Open (S, N);
      Check ("torn record not recovered", N = 3 and S.Head = 3);

      L.Append (S, Put, K ("e"), V ("5"), OK);
      L.Open (S, N);
      Check ("append after torn overwrites it", N = 4 and S.Last_Seq = 4);

      --  Stale record: an old valid block beyond the head with the
      --  wrong sequence must not be picked up.
      declare
         B : Block;
         R : constant Log_Record := (Seq => 99, Kind => Put, K => K ("stale"), V => V ("x"));
      begin
         Encode (R, B);
         Dev.Write (4, B); Dev.Sync;
      end;
      L.Open (S, N);
      Check ("stale valid block with wrong seq stops recovery", N = 4);
   end Test_Log;

   procedure Test_Store is
      N  : Natural;
      OK : Boolean;
      Got : Value;
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
         Check ("get latest", Found and then Same (Got, V ("3")));
         KV.Get (S, K ("y"), Got, Found);
         Check ("get deleted", not Found);
      end;
      declare
         S : KV.Store;
      begin
         KV.Open (S, N);
         Check ("replayed 4", N = 4);
         KV.Get (S, K ("x"), Got, Found);
         Check ("survives reopen", Found and then Same (Got, V ("3")));
         Check ("count after reopen", KV.Count (S) = 1);
      end;
   end Test_Store;

   procedure Test_Capacity is
      N  : Natural;
      OK : Boolean;
      S  : KV.Store;
      Writes_Before : Natural;
   begin
      Dev.Erase;
      KV.Open (S, N);
      for I in 1 .. KV.Max_Entries loop
         KV.Put (S, K ("k" & I'Image), V ("v"), OK);
         exit when not OK;
      end loop;
      --  Max_Entries = 256 but the RAM device has 256 blocks: the log
      --  fills first. Either way Put reports failure, never raises.
      Writes_Before := Dev.Writes;
      KV.Put (S, K ("one more"), V ("v"), OK);
      Check ("put on full store fails cleanly", not OK);
      Check ("no write on refused put", Dev.Writes = Writes_Before);
   end Test_Capacity;

   procedure Test_Wrong_Sequence is
      S : L.State;
      N : Natural;
      OK : Boolean;
      B : Block;
      R : constant Log_Record := (Seq => 99, Kind => Put, K => K ("bad"), V => V ("seq"));
   begin
      Dev.Erase;
      L.Open (S, N);
      L.Append (S, Put, K ("a"), V ("1"), OK);
      L.Append (S, Put, K ("b"), V ("2"), OK);
      Check ("wrong seq setup: 2 appends", OK and N = 0);

      Encode (R, B);
      Dev.Write (2, B);
      Dev.Sync;

      L.Open (S, N);
      Check ("wrong seq stops recovery at 2", N = 2 and S.Head = 2 and S.Last_Seq = 2);
   end Test_Wrong_Sequence;

   procedure Test_Delete_Absent_Key is
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
         Check ("delete absent setup put", OK);
         KV.Delete (S, K ("nonexistent"), OK);
         Check ("delete absent succeeds", OK);
         KV.Get (S, K ("nonexistent"), Got, Found);
         Check ("absent key still not found", not Found);
         KV.Get (S, K ("x"), Got, Found);
         Check ("existing key x preserved", Found and then Same (Got, V ("1")));
         Check ("count remains 1", KV.Count (S) = 1);
      end;
      declare
         S : KV.Store;
      begin
         KV.Open (S, N);
         Check ("reopen after delete absent replays 2", N = 2);
         KV.Get (S, K ("x"), Got, Found);
         Check ("x preserved after reopen", Found and then Same (Got, V ("1")));
         Check ("count after reopen is 1", KV.Count (S) = 1);
      end;
   end Test_Delete_Absent_Key;

   procedure Test_Max_Size_Record is
      Max_K : Key;
      Max_V : Value;
      B     : Block;
      R, D  : Log_Record;
      Valid : Boolean;
      N     : Natural;
      OK    : Boolean;
      Got   : Value;
      Found : Boolean;
      S     : KV.Store;
   begin
      Max_K.Length := Max_Key;
      for I in 1 .. Max_Key loop
         Max_K.Bytes (I) := Byte ((I * 13 + 5) mod 256);
      end loop;
      Max_V.Length := Max_Value;
      for I in 1 .. Max_Value loop
         Max_V.Bytes (I) := Byte ((I * 29 + 11) mod 256);
      end loop;

      R := (Seq => 7, Kind => Put, K => Max_K, V => Max_V);
      Encode (R, B);
      Decode (B, D, Valid);
      Check ("max size encode/decode valid", Valid);
      Check ("max size key round trip", D.K = Max_K);
      Check ("max size value round trip", Same (D.V, Max_V));

      Dev.Erase;
      KV.Open (S, N);
      KV.Put (S, Max_K, Max_V, OK);
      Check ("max size store put", OK);
      KV.Get (S, Max_K, Got, Found);
      Check ("max size store get", Found and then Same (Got, Max_V));
   end Test_Max_Size_Record;

   procedure Test_Drop_Unsynced is
      S  : L.State;
      N  : Natural;
      OK : Boolean;
      B  : Block;
      R  : constant Log_Record := (Seq => 4, Kind => Put, K => K ("unsynced"), V => V ("drop"));
   begin
      Dev.Erase;
      L.Open (S, N);
      L.Append (S, Put, K ("k1"), V ("v1"), OK);
      L.Append (S, Put, K ("k2"), V ("v2"), OK);
      L.Append (S, Put, K ("k3"), V ("v3"), OK);
      Check ("drop unsynced setup: 3 appends", OK);

      Encode (R, B);
      Dev.Write (3, B);
      Dev.Drop_Unsynced;

      L.Open (S, N);
      Check ("unsynced write dropped on recovery", N = 3 and S.Head = 3 and S.Last_Seq = 3);
   end Test_Drop_Unsynced;

   procedure Test_Reference_Map is
      type Ref_Entry is record
         K    : Key;
         V    : Value;
         Live : Boolean := False;
      end record;
      type Ref_Map is array (1 .. 256) of Ref_Entry;

      procedure Ref_Put (M : in out Ref_Map; Target_K : Key; Target_V : Value) is
         Free : Natural := 0;
      begin
         for I in M'Range loop
            if M (I).Live and then M (I).K = Target_K then
               M (I).V := Target_V;
               return;
            elsif not M (I).Live and then Free = 0 then
               Free := I;
            end if;
         end loop;
         if Free /= 0 then
            M (Free) := (K => Target_K, V => Target_V, Live => True);
         end if;
      end Ref_Put;

      procedure Ref_Delete (M : in out Ref_Map; Target_K : Key) is
      begin
         for I in M'Range loop
            if M (I).Live and then M (I).K = Target_K then
               M (I).Live := False;
               return;
            end if;
         end loop;
      end Ref_Delete;

      procedure Ref_Get
        (M : Ref_Map; Target_K : Key; Out_V : out Value; Found : out Boolean) is
      begin
         for I in M'Range loop
            if M (I).Live and then M (I).K = Target_K then
               Out_V := M (I).V;
               Found := True;
               return;
            end if;
         end loop;
         Out_V := (others => <>);
         Found := False;
      end Ref_Get;

      function Ref_Count (M : Ref_Map) return Natural is
         C : Natural := 0;
      begin
         for I in M'Range loop
            if M (I).Live then
               C := C + 1;
            end if;
         end loop;
         return C;
      end Ref_Count;

      procedure Verify_Matches (S : KV.Store; M : Ref_Map; Label : String) is
         Probe_Keys : constant array (1 .. 7) of Key :=
           [K ("alpha"), K ("bravo"), K ("charlie"), K ("delta"),
            K ("echo"), K ("foxtrot"), K ("missing")];
         SV, RV : Value;
         SF, RF : Boolean;
         All_OK : Boolean := True;
      begin
         if KV.Count (S) /= Ref_Count (M) then
            All_OK := False;
         end if;
         for PK of Probe_Keys loop
            KV.Get (S, PK, SV, SF);
            Ref_Get (M, PK, RV, RF);
            if SF /= RF or else (SF and then not Same (SV, RV)) then
               All_OK := False;
            end if;
         end loop;
         Check ("ref map matches store (" & Label & ")", All_OK);
      end Verify_Matches;

      M  : Ref_Map;
      N  : Natural;
      OK : Boolean;
   begin
      Dev.Erase;
      declare
         S : KV.Store;
      begin
         KV.Open (S, N);
         Verify_Matches (S, M, "empty");

         KV.Put (S, K ("delta"), V ("4"), OK);
         Ref_Put (M, K ("delta"), V ("4"));
         Verify_Matches (S, M, "insert delta");

         KV.Put (S, K ("alpha"), V ("1"), OK);
         Ref_Put (M, K ("alpha"), V ("1"));
         Verify_Matches (S, M, "insert first key alpha");

         KV.Put (S, K ("foxtrot"), V ("6"), OK);
         Ref_Put (M, K ("foxtrot"), V ("6"));
         Verify_Matches (S, M, "insert last key foxtrot");

         KV.Put (S, K ("charlie"), V ("3"), OK);
         Ref_Put (M, K ("charlie"), V ("3"));
         Verify_Matches (S, M, "insert between charlie");

         KV.Put (S, K ("bravo"), V ("2"), OK);
         Ref_Put (M, K ("bravo"), V ("2"));
         KV.Put (S, K ("echo"), V ("5"), OK);
         Ref_Put (M, K ("echo"), V ("5"));
         Verify_Matches (S, M, "6 keys");

         KV.Put (S, K ("charlie"), V ("33"), OK);
         Ref_Put (M, K ("charlie"), V ("33"));
         Verify_Matches (S, M, "overwrite charlie");

         KV.Delete (S, K ("alpha"), OK);
         Ref_Delete (M, K ("alpha"));
         Verify_Matches (S, M, "delete first key");

         KV.Delete (S, K ("foxtrot"), OK);
         Ref_Delete (M, K ("foxtrot"));
         Verify_Matches (S, M, "delete last key");

         KV.Delete (S, K ("charlie"), OK);
         Ref_Delete (M, K ("charlie"));
         Verify_Matches (S, M, "delete middle key");
      end;

      declare
         S : KV.Store;
      begin
         KV.Open (S, N);
         Verify_Matches (S, M, "after reopen");
      end;
   end Test_Reference_Map;

begin
   Test_CRC;
   Test_Record;
   Test_Log;
   Test_Store;
   Test_Capacity;
   Test_Wrong_Sequence;
   Test_Delete_Absent_Key;
   Test_Max_Size_Record;
   Test_Drop_Unsynced;
   Test_Reference_Map;
   New_Line;
   if Failures = 0 then
      Put_Line ("all tests passed");
   else
      Put_Line (Failures'Image & " failure(s)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;

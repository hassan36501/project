
with Ada.Text_IO; use Ada.Text_IO;
with Legder; use Legder;
with Legder.File_Device;
with Legder.Store;

procedure File_Device_Showcase is

   package Dev renames Legder.File_Device;

   package KV is new Legder.Store
     (Dev.Block_Count, Dev.Read, Dev.Write, Dev.Sync);

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

   function Img (X : Value) return String is
      S : String (1 .. X.Length);
   begin
      for I in S'Range loop
         S (I) := Character'Val (X.Bytes (I));
      end loop;
      return S;
   end Img;

   OK      : Boolean;
   Found   : Boolean;
   N       : Natural;
   Got     : Value;

begin
   Dev.Initialize ("ledger_store.dat");

   Put_Line ("1. Opening file-backed store");

   declare
      S : KV.Store;
   begin
      KV.Open (S, N);
      Put_Line ("  Recovered records:" & N'Image);

      KV.Put (S, K ("alpha"), V ("100"), OK);

      if not OK then
         raise Program_Error with "Put failed";
      end if;

      KV.Put (S, K ("beta"), V ("200"), OK);

      if not OK then
         raise Program_Error with "Put failed";
      end if;
   end;

   Put_Line ("2. Reopening file-backed store");

   declare
      S : KV.Store;
   begin
      KV.Open (S, N);

      KV.Get (S, K ("alpha"), Got, Found);

      if not Found or else Img (Got) /= "100" then
         raise Program_Error with "Alpha recovery failed";
      end if;

      KV.Get (S, K ("beta"), Got, Found);

      if not Found or else Img (Got) /= "200" then
         raise Program_Error with "Beta recovery failed";
      end if;
   end;

   Dev.Close;

   Put_Line ("File Device Store Integration Passed!");

end File_Device_Showcase;

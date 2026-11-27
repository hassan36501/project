--  Crash-test writer: continuously appends records to a file-backed
--  store so an external script can kill it mid-operation.

with Ada.Command_Line;
with Ada.Text_IO;        use Ada.Text_IO;
with Legder;             use Legder;
with Legder.File_Device;
with Legder.Store;

procedure Crash_Writer is

   package Dev renames Legder.File_Device;
   package KV  is new Legder.Store (Dev.Block_Count, Dev.Read, Dev.Write, Dev.Sync);

   function K (S : String) return Key;
   function V (S : String) return Value;

   function K (S : String) return Key is
      R : Key;
   begin
      R.Length := S'Length;
      for I in S'Range loop
         R.Bytes (I - S'First + 1) := Byte (Character'Pos (S (I)));
      end loop;
      return R;
   end K;

   function V (S : String) return Value is
      R : Value;
   begin
      R.Length := S'Length;
      for I in S'Range loop
         R.Bytes (I - S'First + 1) := Byte (Character'Pos (S (I)));
      end loop;
      return R;
   end V;

   Path : constant String :=
     (if Ada.Command_Line.Argument_Count >= 1
      then Ada.Command_Line.Argument (1)
      else "crash_test.dat");

   S  : KV.Store;
   N  : Natural;
   OK : Boolean;
begin
   Dev.Initialize (Path);
   KV.Open (S, N);
   Put_Line ("Opened with" & N'Image & " existing records");

   for I in 1 .. 500 loop
      KV.Put (S, K ("rec_" & I'Image), V ("payload_" & I'Image), OK);
      exit when not OK;
      if I mod 10 = 0 then
         Put_Line ("Committed" & I'Image);
      end if;
   end loop;

   Dev.Close;
end Crash_Writer;

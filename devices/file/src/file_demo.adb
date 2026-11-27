--  Portable smoke-test program for the file-backed block device.
--  Tests normal write / close / reopen / read, plus S3 table capacity
--  beyond 256 records (using 1024 blocks).

with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;        use Ada.Text_IO;
with Legder;             use Legder;
with Legder.File_Device;
with Legder.Store;

procedure File_Demo is

   package Dev renames Legder.File_Device;
   package KV  is new Legder.Store (Dev.Block_Count, Dev.Read, Dev.Write, Dev.Sync);

   Demo_Path : constant String := "legder_demo.dat";
   Failed    : Boolean := False;

   function K (S : String) return Key;
   function V (S : String) return Value;
   procedure Expect (S : KV.Store; Name : String; Want : String; Present : Boolean := True);

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

   procedure Expect (S : KV.Store; Name : String; Want : String; Present : Boolean := True) is
      Got   : Value;
      Found : Boolean;
   begin
      KV.Get (S, K (Name), Got, Found);
      if Found /= Present or else (Found and then not Same (Got, V (Want))) then
         Put_Line ("  FAIL " & Name);
         Failed := True;
      else
         Put_Line ("  ok   " & Name);
      end if;
   end Expect;

   N  : Natural;
   OK : Boolean;

begin
   if Ada.Directories.Exists (Demo_Path) then
      Ada.Directories.Delete_File (Demo_Path);
   end if;

   Put_Line ("1. Initialize file device and write keys");
   Dev.Initialize (Demo_Path);
   declare
      S : KV.Store;
   begin
      KV.Open (S, N);
      KV.Put (S, K ("motor-speed"), V ("100"), OK);
      KV.Put (S, K ("mode"),        V ("auto"), OK);
      KV.Put (S, K ("motor-speed"), V ("120"), OK);
      KV.Delete (S, K ("mode"), OK);
      KV.Put (S, K ("limit"),       V ("250"), OK);
   end;
   Dev.Close;

   Put_Line ("2. Reopen file device (simulating restart) and verify");
   Dev.Initialize (Demo_Path);
   declare
      S : KV.Store;
   begin
      KV.Open (S, N);
      Put_Line ("  replayed" & N'Image & " records");
      Expect (S, "motor-speed", "120");
      Expect (S, "mode", "", Present => False);
      Expect (S, "limit", "250");
   end;
   Dev.Close;

   --  Clean up demo file before S3 capacity test.
   if Ada.Directories.Exists (Demo_Path) then
      Ada.Directories.Delete_File (Demo_Path);
   end if;

   Put_Line ("3. S3 capacity test: fill 256-entry table with 1024-block log");
   Dev.Initialize (Demo_Path);
   declare
      S : KV.Store;
   begin
      KV.Open (S, N);
      for I in 1 .. KV.Max_Entries loop
         KV.Put (S, K ("key_" & I'Image), V ("val"), OK);
         if not OK then
            Put_Line ("  FAIL unexpected failure at key" & I'Image);
            Failed := True;
            exit;
         end if;
      end loop;
      --  257th distinct key must be refused by table capacity (S3),
      --  even though the 1024-block log still has plenty of space.
      KV.Put (S, K ("key_overflow"), V ("val"), OK);
      if OK then
         Put_Line ("  FAIL expected S3 table-full refusal");
         Failed := True;
      else
         Put_Line ("  ok   S3 refused 257th key cleanly");
      end if;
   end;
   Dev.Close;

   if Ada.Directories.Exists (Demo_Path) then
      Ada.Directories.Delete_File (Demo_Path);
   end if;

   if Failed then
      Put_Line ("FILE DEMO FAILED");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Put_Line ("file demo ok");
   end if;
end File_Demo;


with Ada.Text_IO;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Legder;
with Legder.File_Device;

procedure File_Device_Test is
   use type Legder.Byte_Array;

   Raised : Boolean := False;

   Write_Data : constant Legder.Block := [others => 16#A5#];
   Read_Data  : Legder.Block;

begin
   -- Test 1: Invalid file size
   if Ada.Directories.Exists ("invalid_device_test.dat") then
      Ada.Directories.Delete_File ("invalid_device_test.dat");
   end if;

   declare
      Invalid_File : Ada.Streams.Stream_IO.File_Type;
   begin
      Ada.Streams.Stream_IO.Create
        (Invalid_File,
         Ada.Streams.Stream_IO.Out_File,
         "invalid_device_test.dat");
      Ada.Streams.Stream_IO.Close (Invalid_File);
   end;

   begin
      Legder.File_Device.Initialize ("invalid_device_test.dat");
   exception
      when Program_Error =>
         Raised := True;
   end;

   if not Raised then
      Legder.File_Device.Close;
      raise Program_Error with "Test failed: Invalid file size accepted";
   end if;

   Ada.Directories.Delete_File ("invalid_device_test.dat");

   Ada.Text_IO.Put_Line ("Invalid File Size Test Passed!");

   -- Test 2: Write and Sync
   Legder.File_Device.Initialize ("sync_device_test.dat");

   declare
      Out_Of_Range_Raised : Boolean := False;
   begin
      begin
         Legder.File_Device.Read
           (Legder.File_Device.Block_Count + 1, Read_Data);
      exception
         when Program_Error =>
            Out_Of_Range_Raised := True;
      end;

      if not Out_Of_Range_Raised then
         Legder.File_Device.Close;
         raise Program_Error with "Test failed: Out-of-range read accepted";
      end if;
   end;

   Legder.File_Device.Write (0, Write_Data);
   Legder.File_Device.Sync;
   Legder.File_Device.Close;

   -- Test 3: Reopen and verify persistence
   Legder.File_Device.Initialize ("sync_device_test.dat");

   Legder.File_Device.Read (0, Read_Data);

   if Read_Data /= Write_Data then
      Legder.File_Device.Close;
      raise Program_Error with "Test failed: Data was not preserved";
   end if;

   Legder.File_Device.Close;

   Ada.Text_IO.Put_Line ("Sync and Persistence Test Passed!");

end File_Device_Test;

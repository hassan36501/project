
with Ada.Text_IO;
with Legder;
with Legder.File_Device;

procedure File_Device_Test is
   use type Legder.Byte_Array;

   Raised : Boolean := False;

   Write_Data : constant Legder.Block := [others => 16#A5#];
   Read_Data  : Legder.Block;

begin
   -- Test 1: Invalid file size
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

   Ada.Text_IO.Put_Line ("Invalid File Size Test Passed!");

   -- Test 2: Write and Sync
   Legder.File_Device.Initialize ("sync_device_test.dat");

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

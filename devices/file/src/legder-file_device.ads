--  A block device backed by a regular file, with real OS fsync.
--  SPARK_Mode => Off because we use OS-level I/O.

package Legder.File_Device with SPARK_Mode => Off is

   Block_Count : constant Block_Index := 1023;  --  512 KiB, 1024 blocks

   Device_Error : exception;

   procedure Initialize (Path : String);
   --  Open or create the backing file. Must be called before any
   --  Read / Write / Sync. Raises Device_Error on I/O failure.

   procedure Read  (Index : Block_Index; Data : out Block);
   procedure Write (Index : Block_Index; Data : Block);
   procedure Sync;

   procedure Close;

end Legder.File_Device;

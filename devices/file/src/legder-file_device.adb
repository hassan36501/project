--  File-backed block device using GNAT.OS_Lib and OS fsync.
--  On POSIX (Linux/macOS) Sync calls fsync(fd).
--  Note: on Windows MinGW, fsync may need _commit; CI runs on Ubuntu
--  where POSIX fsync is provided by libc.

with GNAT.OS_Lib;
with Interfaces.C;

package body Legder.File_Device with SPARK_Mode => Off is

   use GNAT.OS_Lib;

   FD      : File_Descriptor := Invalid_FD;
   Is_Open : Boolean := False;

   function C_Fsync (File_FD : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "legder_fsync";

   function To_C_FD (F : File_Descriptor) return Interfaces.C.int is
     (Interfaces.C.int (F));

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (Path : String) is
   begin
      if Is_Open then
         Close;
      end if;

      if Is_Regular_File (Path) then
         FD := Open_Read_Write (Path, Binary);
      else
         FD := Create_File (Path, Binary);
      end if;

      if FD = Invalid_FD then
         raise Device_Error with "Failed to open backing file: " & Path;
      end if;
      Is_Open := True;
   end Initialize;

   ----------
   -- Read --
   ----------

   procedure Read (Index : Block_Index; Data : out Block) is
      Offset : constant Long_Integer := Long_Integer (Index) * Long_Integer (Block_Size);
      Len    : Long_Integer;
      Got    : Integer;
   begin
      Data := [others => 16#FF#];
      if not Is_Open then
         raise Device_Error with "Read on closed file device";
      end if;
      if Index > Block_Count then
         return;
      end if;

      Len := File_Length (FD);
      if Offset >= Len then
         return;
      end if;

      Lseek (FD, Offset, Seek_Set);
      Got := Read (FD, Data (0)'Address, Block_Size);
      if Got < 0 then
         raise Device_Error with "Read error on backing file";
      elsif Got < Block_Size then
         --  Short read: pad remaining bytes with erased value 16#FF#.
         for I in Got .. Block_Size - 1 loop
            Data (I) := 16#FF#;
         end loop;
      end if;
   end Read;

   -----------
   -- Write --
   -----------

   procedure Write (Index : Block_Index; Data : Block) is
      Offset : constant Long_Integer := Long_Integer (Index) * Long_Integer (Block_Size);
      Len    : Long_Integer;
      Erased : constant Block := [others => 16#FF#];
      Wrote  : Integer;
   begin
      if not Is_Open then
         raise Device_Error with "Write on closed file device";
      end if;
      if Index > Block_Count then
         raise Device_Error with "Block index out of range";
      end if;

      --  Extend file with erased blocks if writing past current EOF.
      Len := File_Length (FD);
      if Len < Offset then
         Lseek (FD, Len, Seek_Set);
         declare
            Pad_Bytes : Long_Integer := Offset - Len;
            Chunk     : Integer;
         begin
            while Pad_Bytes > 0 loop
               Chunk := Integer (Long_Integer'Min (Pad_Bytes, Long_Integer (Block_Size)));
               Wrote := Write (FD, Erased (0)'Address, Chunk);
               if Wrote /= Chunk then
                  raise Device_Error with "Failed to extend backing file";
               end if;
               Pad_Bytes := Pad_Bytes - Long_Integer (Chunk);
            end loop;
         end;
      end if;

      Lseek (FD, Offset, Seek_Set);
      Wrote := Write (FD, Data (0)'Address, Block_Size);
      if Wrote /= Block_Size then
         raise Device_Error with "Short write on backing file";
      end if;
   end Write;

   ----------
   -- Sync --
   ----------

   procedure Sync is
      RC : Interfaces.C.int;
      use type Interfaces.C.int;
   begin
      if not Is_Open then
         raise Device_Error with "Sync on closed file device";
      end if;
      RC := C_Fsync (To_C_FD (FD));
      if RC /= 0 then
         raise Device_Error with "fsync failed";
      end if;
   end Sync;

   -----------
   -- Close --
   -----------

   procedure Close is
   begin
      if Is_Open then
         Close (FD);
         FD := Invalid_FD;
         Is_Open := False;
      end if;
   end Close;

end Legder.File_Device;


with Ada.Directories;
with Ada.Direct_IO;
with Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings;

package body Legder.File_Device with SPARK_Mode => Off is

   package Block_IO is new Ada.Direct_IO (Legder.Block);
   use type Block_IO.Count;
   use type Interfaces.C.Strings.chars_ptr;

   use Ada.Strings.Unbounded;

   function Sync_File (Path : Interfaces.C.Strings.chars_ptr)
     return Interfaces.C.int;
   pragma Import (C, Sync_File, "legder_sync_file");

   Device_File : Block_IO.File_Type;
   Device_Path : Unbounded_String;
   Is_Open     : Boolean := False;

   File_Size : constant Block_IO.Count := 256;

   procedure Initialize (Path : String) is
      Erased : constant Legder.Block := [others => 16#FF#];
   begin
      if Is_Open then
         Close;
      end if;

      Device_Path := To_Unbounded_String (Path);

      if Ada.Directories.Exists (Path) then
         Block_IO.Open (Device_File, Block_IO.Inout_File, Path);
      else
         Block_IO.Create (Device_File, Block_IO.Inout_File, Path);

         for I in 1 .. 256 loop
            Block_IO.Write (Device_File, Erased);
         end loop;
      end if;

      if Block_IO.Size (Device_File) /= File_Size then
         Block_IO.Close (Device_File);
         raise Program_Error with "Invalid device file size";
      end if;

      Is_Open := True;
   end Initialize;

   procedure Read
     (Index : Legder.Block_Index;
      Data  : out Legder.Block)
   is
   begin
      if not Is_Open then
         raise Program_Error with "File device is not initialized";
      end if;

      if Index > Block_Count then
         raise Program_Error with "File device block index out of range";
      end if;

      Block_IO.Read
        (Device_File,
         Data,
         From => Block_IO.Positive_Count (Index + 1));
   end Read;

   procedure Write
     (Index : Legder.Block_Index;
      Data  : Legder.Block)
   is
   begin
      if not Is_Open then
         raise Program_Error with "File device is not initialized";
      end if;

      if Index > Block_Count then
         raise Program_Error with "File device block index out of range";
      end if;

      Block_IO.Write
        (Device_File,
         Data,
         To => Block_IO.Positive_Count (Index + 1));
   end Write;

   procedure Sync is
   begin
      if not Is_Open then
         raise Program_Error with "File device is not initialized";
      end if;

      Block_IO.Close (Device_File);
      Is_Open := False;

      declare
         Path_C : Interfaces.C.Strings.chars_ptr :=
           Interfaces.C.Strings.New_String (To_String (Device_Path));
         Result : Interfaces.C.int;
      begin
         Result := Sync_File (Path_C);
         Interfaces.C.Strings.Free (Path_C);
         Path_C := Interfaces.C.Strings.Null_Ptr;
         if Result /= 0 then
            raise Program_Error with "File synchronization failed";
         end if;
      exception
         when others =>
            if Path_C /= Interfaces.C.Strings.Null_Ptr then
               Interfaces.C.Strings.Free (Path_C);
            end if;
            raise;
      end;

      Block_IO.Open
        (Device_File,
         Block_IO.Inout_File,
         To_String (Device_Path));

      Is_Open := True;
   end Sync;

   procedure Close is
   begin
      if Is_Open then
         Block_IO.Close (Device_File);
         Is_Open := False;
      end if;
   end Close;

end Legder.File_Device;

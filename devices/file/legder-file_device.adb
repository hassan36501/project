
with Ada.Directories;
with Ada.Direct_IO;
with Ada.Strings.Unbounded;
with Interfaces.C;
with System;

package body Legder.File_Device with SPARK_Mode => Off is

   package Block_IO is new Ada.Direct_IO (Legder.Block);
   use type Block_IO.Count;

   use Ada.Strings.Unbounded;

   type Win_Handle is new Interfaces.C.ptrdiff_t;
   type Win_DWORD  is new Interfaces.C.unsigned_long;
   type Win_BOOL   is new Interfaces.C.int;

   
   

   INVALID_HANDLE_VALUE : constant Win_Handle := -1;

   GENERIC_WRITE          : constant Win_DWORD := 16#40000000#;
   FILE_SHARE_READ        : constant Win_DWORD := 1;
   FILE_SHARE_WRITE       : constant Win_DWORD := 2;
   OPEN_EXISTING          : constant Win_DWORD := 3;
   FILE_ATTRIBUTE_NORMAL  : constant Win_DWORD := 16#80#;

   function Win_CreateFileA
     (File_Name : System.Address;
      Access_Mode : Win_DWORD;
      Share_Mode : Win_DWORD;
      Security_Attributes : System.Address;
      Creation_Disposition : Win_DWORD;
      Flags_And_Attributes : Win_DWORD;
      Template_Handle : Win_Handle) return Win_Handle;

   pragma Import (Stdcall, Win_CreateFileA, "CreateFileA");

   function Win_FlushFileBuffers
     (File : Win_Handle) return Win_BOOL;

   pragma Import
     (Stdcall, Win_FlushFileBuffers, "FlushFileBuffers");

   function Win_CloseHandle
     (File : Win_Handle) return Win_BOOL;

   pragma Import (Stdcall, Win_CloseHandle, "CloseHandle");

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
         Path_C : aliased String :=
           To_String (Device_Path) & Character'Val (0);

         Handle : Win_Handle;

      begin
         Handle := Win_CreateFileA
           (File_Name => Path_C'Address,
            Access_Mode => GENERIC_WRITE,
            Share_Mode => FILE_SHARE_READ + FILE_SHARE_WRITE,
            Security_Attributes => System.Null_Address,
            Creation_Disposition => OPEN_EXISTING,
            Flags_And_Attributes => FILE_ATTRIBUTE_NORMAL,
            Template_Handle => 0);

         if Handle = INVALID_HANDLE_VALUE then
            raise Program_Error with "Windows CreateFile failed";
         end if;

         begin
            if Win_FlushFileBuffers (Handle) = 0 then
               raise Program_Error with "FlushFileBuffers failed";
            end if;

         exception
            when others =>
               if Win_CloseHandle (Handle) = 0 then
                  raise Program_Error with "Windows CloseHandle failed";
               end if;
               raise;
         end;

         if Win_CloseHandle (Handle) = 0 then
            raise Program_Error with "Windows CloseHandle failed";
         end if;
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

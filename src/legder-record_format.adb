package body Legder.Record_Format with SPARK_Mode is

   Off_Magic  : constant := 0;
   Off_Seq    : constant := 4;
   Off_Kind   : constant := 12;
   Off_KLen   : constant := 13;
   Off_VLen   : constant := 14;
   Off_Key    : constant := 16;
   Off_Value  : constant := 48;
   Off_CRC    : constant := 508;

   function Get_U32 (B : Block; At_Off : Block_Offset) return CRC32
     with
       Pre  => At_Off <= Block_Size - 4,
       Post =>
         Get_U32'Result =
           CRC32 (B (At_Off))
           + CRC32 (B (At_Off + 1)) * 256
           + CRC32 (B (At_Off + 2)) * 65_536
           + CRC32 (B (At_Off + 3)) * 16_777_216;

   procedure Put_U32 (B : in out Block; At_Off : Block_Offset; V : CRC32)
     with
       Pre  => At_Off <= Block_Size - 4,
       Post => Get_U32 (B, At_Off) = V;

   function Get_U64 (B : Block; At_Off : Block_Offset) return Sequence
     with
       Pre  => At_Off <= Block_Size - 8,
       Post =>
         Get_U64'Result =
           Sequence (B (At_Off))
           + Sequence (B (At_Off + 1)) * 256
           + Sequence (B (At_Off + 2)) * 65_536
           + Sequence (B (At_Off + 3)) * 16_777_216
           + Sequence (B (At_Off + 4)) * 4_294_967_296
           + Sequence (B (At_Off + 5)) * 1_099_511_627_776
           + Sequence (B (At_Off + 6)) * 281_474_976_710_656
           + Sequence (B (At_Off + 7)) * 72_057_594_037_927_936;

   procedure Put_U64 (B : in out Block; At_Off : Block_Offset; V : Sequence)
     with
       Pre  => At_Off <= Block_Size - 8,
       Post => Get_U64 (B, At_Off) = V;

   procedure Put_U32 (B : in out Block; At_Off : Block_Offset; V : CRC32) is
      X : CRC32 := V;
   begin
      for I in 0 .. 3 loop
         B (At_Off + I) := Byte (X and 16#FF#);
         X := X / 256;
      end loop;
   end Put_U32;

   function Get_U32 (B : Block; At_Off : Block_Offset) return CRC32 is
      X : CRC32 := 0;
   begin
      for I in reverse 0 .. 3 loop
         X := X * 256 + CRC32 (B (At_Off + I));
      end loop;

      return X;
   end Get_U32;

   procedure Put_U64 (B : in out Block; At_Off : Block_Offset; V : Sequence) is
      X : Sequence := V;
   begin
      for I in 0 .. 7 loop
         B (At_Off + I) := Byte (X and 16#FF#);
         X := X / 256;
      end loop;
   end Put_U64;

   function Get_U64 (B : Block; At_Off : Block_Offset) return Sequence is
      X : Sequence := 0;
   begin
      for I in reverse 0 .. 7 loop
         X := X * 256 + Sequence (B (At_Off + I));
      end loop;

      return X;
   end Get_U64;

   procedure Encode (R : Log_Record; B : out Block) is
   begin
      B := [others => 0];

      Put_U32 (B, Off_Magic, Magic);
      pragma Assert (Get_U32 (B, Off_Magic) = Magic);

      Put_U64 (B, Off_Seq, R.Seq);
      pragma Assert (Get_U64 (B, Off_Seq) = R.Seq);

      B (Off_Kind) := (case R.Kind is
                         when Put    => 0,
                         when Delete => 1);

      B (Off_KLen) := Byte (R.K.Length);
      pragma Assert (Natural (B (Off_KLen)) = R.K.Length);

      B (Off_VLen) := Byte (R.V.Length mod 256);
      B (Off_VLen + 1) := Byte (R.V.Length / 256);

      pragma Assert
        (Natural (B (Off_VLen))
         + 256 * Natural (B (Off_VLen + 1)) = R.V.Length);

      for I in 1 .. R.K.Length loop
         B (Off_Key + I - 1) := R.K.Bytes (I);
      end loop;

      if R.Kind = Put then
         for I in 1 .. R.V.Length loop
            B (Off_Value + I - 1) := R.V.Bytes (I);
         end loop;
      end if;

      Put_U32 (B, Off_CRC, CRC (B (0 .. Off_CRC - 1)));
   end Encode;

   procedure Decode (B : Block; R : out Log_Record; Valid : out Boolean) is
      KL : constant Natural := Natural (B (Off_KLen));
      VL : constant Natural :=
        Natural (B (Off_VLen))
        + 256 * Natural (B (Off_VLen + 1));
   begin
      R := (others => <>);
      Valid := False;

      if Get_U32 (B, Off_Magic) /= Magic then
         return;
      end if;

      if B (Off_Kind) > 1
        or else KL > Max_Key
        or else VL > Max_Value
      then
         return;
      end if;

      if Get_U32 (B, Off_CRC) /= CRC (B (0 .. Off_CRC - 1)) then
         return;
      end if;

      R.Seq := Get_U64 (B, Off_Seq);
      R.Kind := (if B (Off_Kind) = 0 then Put else Delete);

      R.K.Length := KL;

      for I in 1 .. KL loop
         pragma Loop_Invariant
           (for all J in 1 .. I - 1 =>
              R.K.Bytes (J) = B (Off_Key + J - 1));

         R.K.Bytes (I) := B (Off_Key + I - 1);
      end loop;

      pragma Assert
        (for all I in 1 .. KL =>
           R.K.Bytes (I) = B (Off_Key + I - 1));

      if R.Kind = Put then
         R.V.Length := VL;

         for I in 1 .. VL loop
            pragma Loop_Invariant
              (for all J in 1 .. I - 1 =>
                 R.V.Bytes (J) = B (Off_Value + J - 1));

            R.V.Bytes (I) := B (Off_Value + I - 1);
         end loop;

         pragma Assert
           (for all I in 1 .. VL =>
              R.V.Bytes (I) = B (Off_Value + I - 1));
      end if;

      pragma Assert (R.Seq = Get_U64 (B, Off_Seq));

      pragma Assert
        (R.Kind = (if B (Off_Kind) = 0 then Put else Delete));

      pragma Assert (R.K.Length = KL);

      pragma Assert (R.V.Length = (if R.Kind = Put then VL else 0));

      Valid := True;
   end Decode;

end Legder.Record_Format;
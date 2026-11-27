--  The on-disk record: one block, one committed operation.
--
--    offset  size  field
--         0     4  Magic     16#4C444752# ("LDGR")
--         4     8  Sequence  little-endian
--        12     1  Kind      0 = Put, 1 = Delete
--        13     1  Key_Len   0 .. Max_Key
--        14     2  Val_Len   0 .. Max_Value, little-endian
--        16    32  Key       padded with zero
--        48   256  Value     padded with zero
--       304   204  Reserved  zero
--       508     4  CRC       CRC-32 of bytes 0 .. 507, little-endian
--
--  Fixed layout, one record per block. Encode never fails. Decode is
--  total: it returns Valid = False for anything that is not a record,
--  including all-zero and all-FF blocks (erased flash), and a record
--  whose CRC does not match (torn write).
--
--  PROOF TARGET
--    R1  Decode (Encode (R)) is Equivalent to R for every R.
--    R2  Decode never reads outside the block (index safety).
--    R3  A block that Decodes as Valid with CRC matching was produced
--        by Encode, up to CRC collision.  (R3 is documentation, not a
--        proof obligation: CRC is not a proof.)

package Legder.Record_Format with SPARK_Mode is

   Magic : constant := 16#4C444752#;

   type Op_Kind is (Put, Delete);

   type Log_Record is record
      Seq  : Sequence := 0;
      Kind : Op_Kind  := Put;
      K    : Key;
      V    : Value;   --  ignored when Kind = Delete
   end record;
   function Equivalent (Left, Right : Log_Record) return Boolean is
     (Left.Seq = Right.Seq
      and then Left.Kind = Right.Kind
      and then Left.K = Right.K
      and then
        (if Left.Kind = Put
         then Same (Left.V, Right.V)
         else Right.V.Length = 0));

   procedure Encode (R : Log_Record; B : out Block)
     with Global => null;

   procedure Decode (B : Block; R : out Log_Record; Valid : out Boolean)
     with
       Global => null,
       Post =>
         (if Valid then
            R.K.Length = Natural (B (13))
            and then
            (for all I in 1 .. R.K.Length =>
               R.K.Bytes (I) = B (15 + I))
            and then
            R.V.Length =
              (if B (12) = 0 then
                 Natural (B (14)) + 256 * Natural (B (15))
               else
                 0)
            and then
            (if B (12) = 0 then
               (for all I in 1 .. R.V.Length =>
                  R.V.Bytes (I) = B (47 + I))
             else
               True)
            and then
            R.Seq =
              Sequence (B (4))
              + Sequence (B (5)) * 2 ** 8
              + Sequence (B (6)) * 2 ** 16
              + Sequence (B (7)) * 2 ** 24
              + Sequence (B (8)) * 2 ** 32
              + Sequence (B (9)) * 2 ** 40
              + Sequence (B (10)) * 2 ** 48
              + Sequence (B (11)) * 2 ** 56
            and then
            R.Kind = (if B (12) = 0 then Put else Delete));
   --  Valid = True only when Magic, lengths and CRC all check out.
   --  When Valid = False, R is unspecified.

end Legder.Record_Format;

with Legder.Record_Format;

package body Legder.Store with SPARK_Mode is

   function Model_Of (S : Store) return Model_Array is
      Result : Model_Array := [others => <>];
   begin
      for I in Entry_Index loop
         if Integer (I) <= Integer (S.Live) then
            Result (Integer (I)) :=
              (Present => True,
               K       => S.Table (I).K,
               V       => S.Table (I).V);
         end if;
      end loop;

      return Result;
   end Model_Of;

   function Model_Equal
     (Left, Right : Model_Array) return Boolean
   is
   begin
      for I in Left'Range loop
         if Left (I).Present /= Right (I).Present then
            return False;
         end if;

         if Left (I).Present
           and then
             (Left (I).K /= Right (I).K
              or else not Same (Left (I).V, Right (I).V))
         then
            return False;
         end if;
      end loop;

      return True;
   end Model_Equal;

   --  Compare mappings while ignoring one key.
   function Model_Equal_Except
     (Left, Right : Model_Array;
      Except_Key  : Key) return Boolean
   is
      Found : Boolean;
   begin
      for I in Left'Range loop
         if Left (I).Present and then Left (I).K /= Except_Key then
            Found := False;

            for J in Right'Range loop
               if Right (J).Present and then Right (J).K = Left (I).K then
                  if not Same (Right (J).V, Left (I).V) then
                     return False;
                  end if;

                  Found := True;
                  exit;
               end if;
            end loop;

            if not Found then
               return False;
            end if;
         end if;
      end loop;

      for I in Right'Range loop
         if Right (I).Present and then Right (I).K /= Except_Key then
            Found := False;

            for J in Left'Range loop
               if Left (J).Present and then Left (J).K = Right (I).K then
                  if not Same (Left (J).V, Right (I).V) then
                     return False;
                  end if;

                  Found := True;
                  exit;
               end if;
            end loop;

            if not Found then
               return False;
            end if;
         end if;
      end loop;

      return True;
   end Model_Equal_Except;

   --  Ghost query: determine whether the model contains a key.
   function Model_Contains
     (M : Model_Array;
      K : Key) return Boolean
   is
   begin
      for I in M'Range loop
         if M (I).Present and then M (I).K = K then
            return True;
         end if;
      end loop;

      return False;
   end Model_Contains;

   --  Ghost query: return the value associated with a present key.
   function Model_Value
     (M : Model_Array;
      K : Key) return Value
   is
      Result : Value := (others => <>);
   begin
      for I in M'Range loop
         if M (I).Present and then M (I).K = K then
            Result := M (I).V;
            return Result;
         end if;
      end loop;

      --  The function's precondition requires K to be present.
      return Result;
   end Model_Value;

   use Legder.Record_Format;

   function Key_Less (Left, Right : Key) return Boolean;

   function Lower_Bound
     (T    : Entry_Array;
      Live : Natural;
      K    : Key) return Natural;

   function Find
     (T    : Entry_Array;
      Live : Natural;
      K    : Key) return Natural;

   function Free_Slot (Live : Natural) return Natural;

   procedure Apply
     (T    : in out Entry_Array;
      Live : in out Natural;
      R    : Log_Record);

   --  Lexicographical key comparison.
   function Key_Less (Left, Right : Key) return Boolean is
      Common_Length : constant Natural :=
        Natural'Min (Left.Length, Right.Length);
   begin
      for I in 1 .. Common_Length loop
         if Left.Bytes (I) < Right.Bytes (I) then
            return True;
         elsif Left.Bytes (I) > Right.Bytes (I) then
            return False;
         end if;
      end loop;

      return Left.Length < Right.Length;
   end Key_Less;

   --  Find the first position where K could be inserted.
   --  Entries from 1 to Live are maintained in sorted order.
   function Lower_Bound
     (T    : Entry_Array;
      Live : Natural;
      K    : Key) return Natural
   is
      Low  : Natural := 1;
      High : Natural := Live + 1;
      Mid  : Natural;
   begin
      while Low < High loop
         Mid := Low + (High - Low) / 2;

         if Key_Less (T (Entry_Index (Mid)).K, K) then
            Low := Mid + 1;
         else
            High := Mid;
         end if;
      end loop;

      return Low;
   end Lower_Bound;

   --  Binary search. Returns zero when the key is absent.
   function Find
     (T    : Entry_Array;
      Live : Natural;
      K    : Key) return Natural
   is
      Position : constant Natural := Lower_Bound (T, Live, K);
   begin
      if Position <= Live
        and then T (Entry_Index (Position)).K = K
      then
         return Position;
      end if;

      return 0;
   end Find;

   --  Return the next free position, or zero when full.
   function Free_Slot (Live : Natural) return Natural is
   begin
      if Live < Max_Entries then
         return Live + 1;
      end if;

      return 0;
   end Free_Slot;

   --  Apply one committed record while preserving sorted order.
   procedure Apply
     (T    : in out Entry_Array;
      Live : in out Natural;
      R    : Log_Record)
   is
      I : constant Natural := Find (T, Live, R.K);
   begin
      case R.Kind is

         when Put =>
            if I /= 0 then

               --  Existing key: update its value.
               T (Entry_Index (I)).V := R.V;

            else

               --  New key: insert at its sorted position.
               declare
                  Position : constant Natural :=
                    Lower_Bound (T, Live, R.K);
               begin
                  if Free_Slot (Live) /= 0 then

                     --  Shift entries right to make room.
                     for J in reverse Position .. Live loop
                        T (Entry_Index (J + 1)) :=
                          T (Entry_Index (J));
                     end loop;

                     T (Entry_Index (Position)) :=
                       (Live => True, K => R.K, V => R.V);

                     Live := Live + 1;
                  end if;

                  --  If full during replay, no new slot is available.
               end;
            end if;

         when Delete =>
            if I /= 0 then

               --  Shift following entries left.
               for J in I .. Live - 1 loop
                  T (Entry_Index (J)) :=
                    T (Entry_Index (J + 1));
               end loop;

               T (Entry_Index (Live)).Live := False;
               Live := Live - 1;
            end if;

      end case;
   end Apply;

   ----------
   -- Open --
   ----------

   procedure Open (S : out Store; Replayed : out Natural) is

      procedure Visit (R : Log_Record);

      procedure Visit (R : Log_Record) is
      begin
         Apply (S.Table, S.Live, R);
      end Visit;

      procedure Replay_All is new L.Scan (Visit);

   begin
      S.Table := [others => <>];
      S.Live := 0;

      L.Open (S.Log, Replayed);
      Replay_All (S.Log);
   end Open;

   ---------
   -- Put --
   ---------

   procedure Put
     (S       : in out Store;
      K       : Key;
      V       : Value;
      Success : out Boolean)
   is
   begin
      --  Reject a new key before writing when the table is full.
      if Find (S.Table, S.Live, K) = 0
        and then Free_Slot (S.Live) = 0
      then
         Success := False;
         return;
      end if;

      --  Preserve original commit order.
      L.Append (S.Log, Record_Format.Put, K, V, Success);

      if Success then
         Apply
           (S.Table,
            S.Live,
            (Seq  => S.Log.Last_Seq,
             Kind => Record_Format.Put,
             K    => K,
             V    => V));
      end if;
   end Put;

   ------------
   -- Delete --
   ------------

   procedure Delete
     (S       : in out Store;
      K       : Key;
      Success : out Boolean)
   is
      None : Value;
   begin
      L.Append (S.Log, Record_Format.Delete, K, None, Success);

      if Success then
         Apply
           (S.Table,
            S.Live,
            (Seq  => S.Log.Last_Seq,
             Kind => Record_Format.Delete,
             K    => K,
             V    => None));
      end if;
   end Delete;

   ---------
   -- Get --
   ---------

   procedure Get
     (S     : Store;
      K     : Key;
      V     : out Value;
      Found : out Boolean)
   is
      I : constant Natural := Find (S.Table, S.Live, K);
   begin
      if I = 0 then
         V := (others => <>);
         Found := False;
      else
         V := S.Table (Entry_Index (I)).V;
         Found := True;
      end if;
   end Get;

   -----------
   -- Count --
   -----------

   function Count (S : Store) return Natural is
     (S.Live);

end Legder.Store;
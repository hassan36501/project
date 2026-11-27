with Legder.Record_Format;
package body Legder.Store with SPARK_Mode is

   use Legder.Record_Format;

   --  Sorted array index with binary search. Table (1 .. Live) is kept
   --  sorted in ascending "<" order by Key.

   function Find (T : Entry_Array; Live : Natural; K : Key) return Natural;
   function Insert_At (T : Entry_Array; Live : Natural; K : Key) return Positive;
   procedure Apply (T : in out Entry_Array; Live : in out Natural; R : Log_Record);

   function Find (T : Entry_Array; Live : Natural; K : Key) return Natural is
      Lo  : Positive := 1;
      Hi  : Natural  := Live;
      Mid : Positive;
   begin
      while Lo <= Hi loop
         Mid := Lo + (Hi - Lo) / 2;
         if T (Entry_Index (Mid)).K = K then
            return Mid;
         elsif T (Entry_Index (Mid)).K < K then
            Lo := Mid + 1;
         else
            Hi := Mid - 1;
         end if;
      end loop;
      return 0;
   end Find;

   function Insert_At (T : Entry_Array; Live : Natural; K : Key) return Positive is
      Lo  : Positive := 1;
      Hi  : Natural  := Live;
      Mid : Positive;
   begin
      while Lo <= Hi loop
         Mid := Lo + (Hi - Lo) / 2;
         if T (Entry_Index (Mid)).K < K then
            Lo := Mid + 1;
         else
            Hi := Mid - 1;
         end if;
      end loop;
      return Lo;
   end Insert_At;

   --  Apply one record to the table. Used by Open (replay) and by
   --  Put/Delete (after commit). One code path, so replay and live
   --  updates cannot drift apart.
   procedure Apply (T : in out Entry_Array; Live : in out Natural; R : Log_Record) is
      Pos : constant Natural := Find (T, Live, R.K);
   begin
      case R.Kind is
         when Put =>
            if Pos /= 0 then
               T (Entry_Index (Pos)).V := R.V;
            elsif Live < Max_Entries then
               declare
                  Ins : constant Positive := Insert_At (T, Live, R.K);
               begin
                  for I in reverse Ins .. Live loop
                     T (Entry_Index (I + 1)) := T (Entry_Index (I));
                  end loop;
                  T (Entry_Index (Ins)) := (K => R.K, V => R.V);
                  Live := Live + 1;
               end;
            end if;
         when Delete =>
            if Pos /= 0 then
               for I in Pos .. Live - 1 loop
                  T (Entry_Index (I)) := T (Entry_Index (I + 1));
               end loop;
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

   procedure Put (S : in out Store; K : Key; V : Value; Success : out Boolean) is
   begin
      if Find (S.Table, S.Live, K) = 0 and then S.Live >= Max_Entries then
         Success := False;  --  S3: refuse before touching the log
         return;
      end if;
      L.Append (S.Log, Record_Format.Put, K, V, Success);
      if Success then
         Apply (S.Table, S.Live,
                (Seq => S.Log.Last_Seq, Kind => Record_Format.Put, K => K, V => V));
      end if;
   end Put;

   ------------
   -- Delete --
   ------------

   procedure Delete (S : in out Store; K : Key; Success : out Boolean) is
      None : Value;
   begin
      L.Append (S.Log, Record_Format.Delete, K, None, Success);
      if Success then
         Apply (S.Table, S.Live,
                (Seq => S.Log.Last_Seq, Kind => Record_Format.Delete, K => K, V => None));
      end if;
   end Delete;

   ---------
   -- Get --
   ---------

   procedure Get (S : Store; K : Key; V : out Value; Found : out Boolean) is
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

   function Count (S : Store) return Natural is (S.Live);

   function Has_Key (S : Store; K : Key) return Boolean is
     (Find (S.Table, S.Live, K) /= 0);

   function Get_Value (S : Store; K : Key) return Value is
     (S.Table (Entry_Index (Find (S.Table, S.Live, K))).V);

end Legder.Store;

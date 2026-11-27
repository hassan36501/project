package body Reference_Model is

   use type Legder.Key;

   function Find
     (M : Model;
      K : Legder.Key) return Natural
   is
   begin
      for I in 1 .. Max_Entries loop
         if M.Entries (I).Live
           and then M.Entries (I).K = K
         then
            return I;
         end if;
      end loop;

      return 0;
   end Find;

   procedure Clear (M : out Model) is
   begin
      M := (Entries => [others => <>], Count => 0);
   end Clear;

   procedure Put
     (M : in out Model;
      K : Legder.Key;
      V : Legder.Value;
      Success : out Boolean)
   is
      Position : constant Natural := Find (M, K);
   begin
      if Position /= 0 then
         M.Entries (Position).V := V;
         Success := True;
         return;
      end if;

      if M.Count = Max_Entries then
         Success := False;
         return;
      end if;

      for I in 1 .. Max_Entries loop
         if not M.Entries (I).Live then
            M.Entries (I) :=
              (Live => True, K => K, V => V);

            M.Count := M.Count + 1;
            Success := True;
            return;
         end if;
      end loop;

      Success := False;
   end Put;

   procedure Delete
     (M : in out Model;
      K : Legder.Key)
   is
      Position : constant Natural := Find (M, K);
   begin
      if Position /= 0 then
         M.Entries (Position).Live := False;
         M.Count := M.Count - 1;
      end if;
   end Delete;

   procedure Get
     (M : Model;
      K : Legder.Key;
      V : out Legder.Value;
      Found : out Boolean)
   is
      Position : constant Natural := Find (M, K);
   begin
      if Position = 0 then
         V := (others => <>);
         Found := False;
      else
         V := M.Entries (Position).V;
         Found := True;
      end if;
   end Get;

   function Count (M : Model) return Natural is
     (M.Count);

end Reference_Model;

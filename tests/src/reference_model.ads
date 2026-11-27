
with Legder;

package Reference_Model is

   Max_Entries : constant := 256;

   type Model_Entry is record
      Live  : Boolean := False;
      K     : Legder.Key;
      V     : Legder.Value;
   end record;

   type Model_Array is
     array (Positive range 1 .. Max_Entries) of Model_Entry;

   type Model is record
      Entries : Model_Array := [others => <>];
      Count   : Natural := 0;
   end record;

   procedure Clear (M : out Model);

   procedure Put
     (M : in out Model;
      K : Legder.Key;
      V : Legder.Value;
      Success : out Boolean);

   procedure Delete
     (M : in out Model;
      K : Legder.Key);

   procedure Get
     (M : Model;
      K : Legder.Key;
      V : out Legder.Value;
      Found : out Boolean);

   function Count (M : Model) return Natural;

end Reference_Model;

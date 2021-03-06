module CheckerTest exposing (suite)

import Test exposing (Test, describe)
import Expect
import HdlChecker exposing (Type(..), Problem(..), SizeComparator(..))
import HdlParser exposing (Size(..), BindingTarget(..), Expr(..))
import AssocList as Dict

suite : Test
suite =
  describe "Checker"
    [ describe "Prelude"
      [ Test.test "Using prelude functions" <|
        \_ ->
          let
            src =
              "not a[1] -> [1] = nand a a"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      ]
    , describe "Bus Size"
      [ Test.test "Omit param bus size and default to 1" <|
        \_ ->
          let
            src =
              "not a -> [1] = nand a a"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , Test.test "Return type bus size too large" <|
        \_ ->
          let
            src =
              "not a[2] -> [1] = nand a a"
            expected =
              Err [ MismatchedTypes { from = (1,13), to = (1,16), value = TBus (IntSize 1) EqualToSize } { from = (1,19), to = (1,27), value = TBus (IntSize 2) EqualToSize }]
          in
          Expect.equal expected (check src)
      , Test.test "Arg type bus size too large" <|
        \_ ->
          let
            src =
              "not a -> [1] = nand a a\nusing_not a[2] -> [2] = not a"
            expected =
              Err [MismatchedTypes { from = (2,19), to = (2,22), value = TBus (IntSize 2) EqualToSize } { from = (2,25), to = (2,30), value = TBus (IntSize 1) EqualToSize },MismatchedTypes { from = (1,5), to = (1,6), value = TBus (IntSize 1) EqualToSize } { from = (2,29), to = (2,30), value = TBus (IntSize 2) EqualToSize }]
          in
          Expect.equal expected (check src)
      , Test.test "Use user-defined functions" <|
        \_ ->
          let
            src =
              "not a -> [1] = nand a a\nor a b -> [1] = nand (not a) (not b)"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , Test.test "Variable parameter bus size" <|
        \_ ->
          let
            src =
              "not a[n] -> [n] = nand a a"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , Test.test "VarSize output does not match declared IntSize return type" <|
        \_ ->
          let
            src =
              "not a[n] -> [1] = nand a a"
            expected =
              Err [MismatchedTypes { from = (1,13), to = (1,16), value = TBus (IntSize 1) EqualToSize } { from = (1,19), to = (1,27), value = TBus (VarSize { from = (-1, -1), to = (-1, -1), value = "n" }) EqualToSize }]
          in
          Expect.equal expected (check src)
      ]
      , describe "Undefined names"
      [ Test.test "Undefined function name" <|
        \_ ->
          let
            src =
              "or a b -> [1] = nand (not a) (not b)"
            expected =
              Err [UndefinedName { from = (1,23), to = (1,26), value = "not" }]
          in
          Expect.equal expected (check src)
      , Test.test "Undefined function names" <|
        \_ ->
          let
            src =
              "half_adder a b -> { sum, carry } =\n  let\n    sum = xor a b\n    carry = and a b\n  in\n  { sum = sum, carry = carry }"
            expected =
              Err [UndefinedName { from = (3,11), to = (3,14), value = "xor" }]
          in
          Expect.equal expected (check src)
      , Test.test "Undefined binding name" <|
        \_ ->
          let
            src =
              "not a -> [1] = nand a b"
            expected =
              Err [UndefinedName { from = (1,23), to = (1,24), value = "b" }]
          in
          Expect.equal expected (check src)
      ]
      , describe "Records"
      [ Test.test "Record output" <|
        \_ ->
          let
            src =
              "combine a b -> { a, b } = { a = a, b = b }"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , Test.test "Record output does not match declared record return type" <|
        \_ ->
          let
            src =
              "combine a b -> { a, b } = { a = a, c = b }"
            expected =
              Err [MismatchedTypes { from = (1,27), to = (1,43), value = TRecord (Dict.fromList [("c",{ from = (1,11), to = (1,12), value = TVar { from = (1,11), to = (1,12), value = "T1" } }),("a", { from = (1,9), to = (1,10), value = TVar { from = (1,9), to = (1,10), value = "T0" } })]) } { from = (1,16), to = (1,24), value = TRecord (Dict.fromList [("b",{ from = (1,21), to = (1,22), value = TBus (IntSize 1) EqualToSize }),("a",{ from = (1,18), to = (1,19), value = TBus (IntSize 1) EqualToSize })]) }]
          in
          Expect.equal expected (check src)
      , Test.test "Record assignment in locals" <|
        \_ ->
          let
            src =
              "combine a b -> { a, b } =\n  let { a = a1, b = b1 } = { a = a, b = b } in\n  { a = a1, b = b1 }"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , Test.test "Undefined name in record literal" <|
        \_ ->
          let
            src =
              "combine a b -> { a, b } =\n  let { a = a1, b = b1 } = { a = a, b = b } in\n  { a = a1, b = c1 }"
            expected =
              Err [UndefinedName { from = (3,17), to = (3,19), value = "c1" }]
          in
          Expect.equal expected (check src)
      ]
      , describe "Int literal"
      [ Test.test "direct assignment of decimal" <|
        \_ ->
          let
            src =
              "f i -> [1] = let a = 199 in i"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , Test.test "direct assignment of hexadecimal" <|
        \_ ->
          let
            src =
              "f i -> [1] = let a = 0xFF in i"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , Test.test "direct assignment of binary" <|
        \_ ->
          let
            src =
              "f i -> [1] = let a = 0b1011101 in i"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , Test.test "use in record literals" <|
        \_ ->
          let
            src =
              "f i -> [1] = let r = { a = 0, b = 10 } in i"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , Test.test "use in call" <|
      \_ ->
        let
          src =
            "f i -> [1] = let a = nand 28 29 in i"
          expected =
            Ok ()
        in
        Expect.equal expected (check src)
      , Test.test "mixing different bases" <|
      \_ ->
        let
          src =
            "f i -> [1] = let a = nand 0x23 0b00100011 in i"
          expected =
            Ok ()
        in
        Expect.equal expected (check src)
      ]
      , describe "Call"
      [ Test.test "simple call" <|
        \_ ->
          let
            src =
              "f i -> [1] = let a = nand 0 0 in i"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , Test.test "call arity too small" <|
        \_ ->
          let
            src =
              "f i -> [1] = let a = nand 0 in i"
            expected =
              Err [ WrongCallArity { from = (1,22), to = (1,26), value = "nand" } [{ from = (1,27), to = (1,28), value = TBus (IntSize 1) EqualToSize },{ from = (1,27), to = (1,28), value = TBus (IntSize 1) EqualToSize }] [{ from = (1,27), to = (1,28), value = TBus (IntSize 1) EqualToSize }]]
          in
          Expect.equal expected (check src)
      , Test.test "call arity too big" <|
        \_ ->
          let
            src =
              "f i -> [1] = let a = nand 0 0 0 in i"
            expected =
              Err [ WrongCallArity { from = (1,22), to = (1,26), value = "nand" } [{ from = (-1,-1), to = (-1,-1), value = TBus (VarSize { from = (-1,-1), to = (-1,-1), value = "n" }) EqualToSize },{ from = (-1,-1), to = (-1,-1), value = TBus (VarSize { from = (-1,-1), to = (-1,-1), value = "n" }) EqualToSize }] [{ from = (1,27), to = (1,28), value = TBus (IntSize 1) EqualToSize },{ from = (1,29), to = (1,30), value = TBus (IntSize 1) EqualToSize },{ from = (1,31), to = (1,32), value = TBus (IntSize 1) EqualToSize }]]
          in
          Expect.equal expected (check src)
      ]
      , describe "Indexing"
      [ test "Indexing a IntSize bus"
        "head bus[1] -> [1] = bus[0]" <|
        Ok ()

      , test "Indexing a VarSize bus"
        "head bus[n] -> [1] = bus[0]" <|
        Err [DowncastingDeclaredVarSizeToIntSize { from = (1,1), to = (1,5), value = "n" } { from = (1,22), to = (1,25), value = (0,GreaterThanSize) }]
      
      , test "Slicing a bus"
        "first4 bus[16] -> [4] = bus[0..3]" <|
        Ok ()
      
      ,  test "Index out of bounds"
        "head bus[2] -> [1] = bus[2]" <|
        Err [MismatchedTypes { from = (1,10), to = (1,11), value = TBus (IntSize 2) EqualToSize } { from = (1,22), to = (1,25), value = TBus (IntSize 2) GreaterThanSize }]
      
      , test "end index out of bounds"
        "first4 bus[3] -> [4] = bus[0..3]" <|
        Err [MismatchedTypes { from = (1,12), to = (1,13), value = TBus (IntSize 3) EqualToSize } { from = (1,24), to = (1,27), value = TBus (IntSize 3) GreaterThanSize }]
      
      , test "start index out of bounds"
        "first4 bus[3] -> [4] = bus[3..4]" <|
        Err [MismatchedTypes { from = (1,12), to = (1,13), value = TBus (IntSize 3) EqualToSize } { from = (1,24), to = (1,27), value = TBus (IntSize 4) GreaterThanSize },MismatchedTypes { from = (1,19), to = (1,20), value = TBus (IntSize 4) EqualToSize } { from = (1,24), to = (1,33), value = TBus (IntSize 2) EqualToSize }]
      
      , test "start index greater than end index"
        "first4 bus[3] -> [2] = bus[2..1]" <|
        Err [FromIndexBiggerThanToIndex { from = (1,28), to = (1,29), value = 2 } { from = (1,31), to = (1,32), value = 1 }]
      ]
      , describe "BindingNotAllowedAtTopLevel"
      [ test "binding not allowed at top level"
        "my_binding = nand 0 0" <|
        Err [BindingNotAllowedAtTopLevel { from = (1,1), to = (1,11), value = BindingName "my_binding" }]
      ]
      , describe "DuplicatedName"
      [ test "duplicated top level name"
        "duplicated i[1] -> [1] = nand i 0\nduplicated i[1] -> [1] = nand i 1" <|
        Err [DuplicatedName { from = (1,1), to = (1,11), value = "duplicated" } { from = (2,1), to = (2,11), value = "duplicated" }]
      , test "duplicated local name"
        "f i[1] -> [1] =\n let\n  duplicated = nand i 0\n  duplicated = nand i 1\n in\n 0" <|
        Err [DuplicatedName { from = (3,3), to = (3,13), value = "duplicated" } { from = (4,3), to = (4,13), value = "duplicated" }]
      , test "duplicated local name previously defined at top level"
        "duplicated i[1] -> [1] = nand i 0\nf i[1] -> [1] =\n let\n  duplicated = nand i 1\n in\n 0" <|
        Err [DuplicatedName { from = (1,1), to = (1,11), value = "duplicated" } { from = (4,3), to = (4,13), value = "duplicated" }]
      ]
      , describe "bus literal"
      [ test "simple bus literal containing int literals"
        "f i[1] -> [3] =\n let\n  bus = [ 0, 1, 0 ]\n in\n bus" <|
        Ok ()
      , test "bus literal containing names"
        "f a[1] b[1] c[1] -> [3] =\n let\n  bus = [a, b, c]\n in\n bus" <|
        Ok ()
      , test "bus literal containing mixed names and int literals"
        "f a[1] b[1] c[1] -> [4] =\n let\n  bus = [1, a, 0, b]\n in\n bus" <|
        Ok ()
      , test "bus literal with oversized elements"
        "f a[1] b[1] c[1] -> [4] =\n let\n  bus = [1, a, 2, b]\n in\n bus" <|
        Err [BusLiteralElementTooLarge 2 { from = (3,16), to = (3,17), value = IntLiteral { from = (3,16), to = (3,17), value = 2 } }]
      , test "bus literal with elements that are not bus type"
        "f a[1] b[1] c[1] -> [4] =\n let\n  record = { a = 2 }\n  bus = [1, a, record, b]\n in\n bus" <|
        Err [ExpectingBusLiteralElement { from = (3,12), to = (3,21), value = TRecord (Dict.fromList [("a",{ from = (3,18), to = (3,19), value = TBus (IntSize 2) EqualToSize })]) }]
      ]
      , describe "concatenation"
      [ test "single concatenation of bus literals containing int literals"
        "f i[1] -> [4] =\n let\n  bus = [ 0, 1 ] ++ [ 0, 0 ]\n in\n bus" <|
        Ok ()
      , test "double concatenations of bus literals containing int literals"
        "f i[1] -> [6] =\n let\n  bus = [ 0, 1 ] ++ [ 0, 0 ] ++ [ 1, 0 ]\n in\n bus" <|
        Ok ()
      , test "double concatenations of bus literals containing int literals and names"
        "f i[1] -> [6] =\n let\n  bus = [ 0, i ] ++ [ i, 0 ] ++ [ 1, i ]\n in\n bus" <|
        Ok ()
      , test "double concatenations of bus literals, int literals, and names"
        "f i[1] -> [7] =\n let\n  bus = [ 0, i ] ++ 15 ++ i[0]\n in\n bus" <|
        Ok ()
      , test "single concatenation of bus literal and name"
        "f i[4] -> [3] =\n let\n  bus = [ 0, i[0] ] ++ 0\n in\n bus" <|
        Ok ()
      , test "concat operand has a variable size"
        "f i[4] -> [6] =\n let\n  bus = [ 0, i[0] ] ++ i\n in\n bus" <|
        Err [ConcatOperandHasUncertainSize { from = (3,24), to = (3,25), value = TBus (IntSize 0) GreaterThanSize }]
      , test "concat operand is not a bus"
        "f i[1] -> [3] =\n let\n  bus = [ 0, i ] ++ { a = 2 }\n in\n bus" <|
        Err [ExpectingConcatOperand { from = (3,21), to = (3,30), value = TRecord (Dict.fromList [("a",{ from = (3,27), to = (3,28), value = TBus (IntSize 2) EqualToSize })]) }]
      ]
      , describe "CastingOneDeclaredVarSizeToAnother"
      [ test "identity function"
        "f2 a[m] -> [n] = id a\nid a[n] -> [n] = a" <|
        Err [MismatchedTypes { from = (1,6), to = (1,7), value = TBus (VarSize { from = (1,1), to = (1,3), value = "m" }) EqualToSize } { from = (1,13), to = (1,14), value = TBus (VarSize { from = (1,1), to = (1,3), value = "n" }) EqualToSize }]
      , test "and gate"
        "and a[x] b[y] -> [x] =\n let\n  nand_a_b = nand a b\n in\n nand nand_a_b nand_a_b" <|
        Err [MismatchedTypes { from = (1,12), to = (1,13), value = TBus (VarSize { from = (1,1), to = (1,4), value = "y" }) EqualToSize } { from = (1,19), to = (1,20), value = TBus (VarSize { from = (1,1), to = (1,4), value = "x" }) EqualToSize }]
      , test "mux"
        """mux a[a] b[b] sel[1] -> [c] =
    let
        sel_a =
            and (not (fill sel)) a
        sel_b =
            and (fill sel) b
    in
    or sel_a sel_b

or a[n] b[n] -> [n] =
    nand (not a) (not b)

not a[n] -> [n] =
    nand a a

and a[n] b[n] -> [n] =
    let
        nand_a_b = nand a b
    in
    nand nand_a_b nand_a_b
        """ <|
        Err [MismatchedTypes { from = (1,7), to = (1,8), value = TBus (VarSize { from = (1,1), to = (1,4), value = "a" }) EqualToSize } { from = (1,26), to = (1,27), value = TBus (VarSize { from = (1,1), to = (1,4), value = "c" }) EqualToSize }]
      ]
      , describe "tricky tests"
      [ test "pair"
      """pair a[n] -> { a[n], b[n] } =
    { a = a, b = a }

test_pair a[n] -> { a[n], b[n] } =
    let
        pair1 =
            pair 1
        pair2 =
            pair a
    in
    pair2""" <|
        Ok ()
      , test "3 nands"
      """test i[i] j[j] k[k] -> [j] =
  let
    a = nand i i
    b = nand j j
    c = nand k k
  in
  b""" <|
        Ok ()
      , test "bad 3 nands"
      """test i[i] j[j] k[k] -> [j] =
  let
    a = nand i i
    b = nand j j
    c = nand k k
  in
  c""" <|
        Err [MismatchedTypes { from = (1,18), to = (1,19), value = TBus (VarSize { from = (1,1), to = (1,5), value = "k" }) EqualToSize } { from = (1,25), to = (1,26), value = TBus (VarSize { from = (1,1), to = (1,5), value = "j" }) EqualToSize }]
      ]
    ]

test : String -> String -> Result (List HdlChecker.Problem) () -> Test
test name src expected =
  Test.test name <|
    \_ -> Expect.equal expected (check src)

check : String -> Result (List HdlChecker.Problem) ()
check src =
  case HdlParser.parse src of
    Err deadEnds -> -- parse error should never happen when testing the checker
      Err [ UndefinedName <| HdlParser.fakeLocated <| HdlParser.showDeadEnds src deadEnds]
    Ok program ->
      HdlChecker.check program 
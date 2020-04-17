module CheckerTest exposing (suite)

import Test exposing (Test, describe, test)
import Expect
import HdlChecker exposing (Type(..), Problem(..))
import HdlParser exposing (Size(..))

suite : Test
suite =
  describe "Checker"
    [ describe "Basics"
      [ test "Using prelude functions" <|
        \_ ->
          let
            src =
              "not a[1] -> [1] = nand a a"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , test "Omit param bus size and default to 1" <|
        \_ ->
          let
            src =
              "not a -> [1] = nand a a"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , test "Return type bus size too large" <|
        \_ ->
          let
            src =
              "not a[2] -> [1] = nand a a"
            expected =
              Err [ MismatchedTypes { from = (1,14), to = (1,15), value = BusType (IntSize 1) } { from = (1,19), to = (1,27), value = BusType (IntSize 2) }]
          in
          Expect.equal expected (check src)
      , test "Arg type bus size too large" <|
        \_ ->
          let
            src =
              "not a -> [1] = nand a a\nusing_not a[2] -> [2] = not a"
            expected =
              Err [MismatchedTypes { from = (1,5), to = (1,6), value = BusType (IntSize 1) } { from = (2,29), to = (2,30), value = BusType (IntSize 2) }]
          in
          Expect.equal expected (check src)
      , test "Use user-defined functions" <|
        \_ ->
          let
            src =
              "not a -> [1] = nand a a\nor a b -> [1] = nand (not a) (not b)"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , test "Variable parameter bus size" <|
        \_ ->
          let
            src =
              "not a[n] -> [n] = nand a a"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      , test "VarSize output does not match declared IntSize return type" <|
        \_ ->
          let
            src =
              "not a[n] -> [1] = nand a a"
            expected =
              Err [MismatchedTypes { from = (1,14), to = (1,15), value = BusType (IntSize 1) } { from = (1,19), to = (1,27), value = BusType (VarSize "n" Nothing) }]
          in
          Expect.equal expected (check src)
      , test "Undefined function name" <|
        \_ ->
          let
            src =
              "or a b -> [1] = nand (not a) (not b)"
            expected =
              Err [UndefinedName { from = (1,31), to = (1,34), value = "not" },UndefinedName { from = (1,23), to = (1,26), value = "not" }]
          in
          Expect.equal expected (check src)
      , test "Undefined function names" <|
        \_ ->
          let
            src =
              "half_adder a b -> { sum, carry } =\n  let\n    sum = xor a b\n    carry = and a b\n  in\n  { sum = sum, carry = carry }"
            expected =
              Err [UndefinedName { from = (3,11), to = (3,14), value = "xor" },UndefinedName { from = (4,13), to = (4,16), value = "and" }]
          in
          Expect.equal expected (check src)
      , test "Undefined binding name" <|
        \_ ->
          let
            src =
              "not a -> [1] = nand a b"
            expected =
              Err [UndefinedName { from = (1,23), to = (1,24), value = "b" }]
          in
          Expect.equal expected (check src)
      , test "Record output" <|
        \_ ->
          let
            src =
              "combine a b -> { a, b } = { a = a, b = b }"
            expected =
              Ok ()
          in
          Expect.equal expected (check src)
      ]
    ]

check : String -> Result (List HdlChecker.Problem) ()
check src =
  case HdlParser.parse src of
    Err _ -> -- parse error should never happen when testing the checker
      Err [ UndefinedName <| HdlParser.fakeLocated "Parse Error!!!"]
    Ok program ->
      HdlChecker.check program
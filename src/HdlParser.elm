module HdlParser exposing (parse)

import Parser.Advanced exposing (..)
import Set exposing (Set)


type alias Program =
  List Def


type Def
  = FuncDef
    { name : String
    , params : List Param
    , retSize : Int
    , locals : List Def
    , body : Expr
    }
  | BindingDef
    { name : String
    , locals : List Def
    , body : Expr
    }


type Expr
  = Binding String
  | Call String (List String)


type alias Param =
  { name : String
  , size : Int
  }


type Problem
  = ExpectingName
  | ExpectingInt
  | InvalidNumber
  | ExpectingLeftBracket
  | ExpectingRightBracket
  | ExpectingLet
  | ExpectingIn
  | ExpectingEqual
  | ExpectingEOF
  | ExpectingArrow
  | ExpectingStartOfLineComment
  | ExpectingStartOfMultiLineComment
  | ExpectingEndOfMultiLineComment


type Context
  = DefContext


type alias HdlParser a =
  Parser Context Problem a


reserved : Set String
reserved =
  Set.fromList
    [ "let", "in" ]


parse : String -> Result (List (DeadEnd Context Problem)) Program
parse string =
  run (succeed identity |= defs |. end ExpectingEOF) string


defs : HdlParser (List Def)
defs =
  loop [] <| \revDefs ->
    oneOf
    [ succeed (\d -> Loop (d :: revDefs))
      |. sps
      |= def
      |. sps
    , succeed ()
      |> map (\_ -> Done (List.reverse revDefs))
    ]


def : HdlParser Def
def =
  succeed
    (\defName defHeader defLocals defBody ->
      let
        _ = Debug.log "AL -> defName" <| defName
      in
      case defHeader of
        Just (defParams, defRetSize) ->
          FuncDef { name = defName
          , params = defParams
          , retSize = defRetSize
          , locals = Maybe.withDefault [] defLocals
          , body = defBody
          }
        Nothing ->
          BindingDef { name = defName
          , locals = Maybe.withDefault [] defLocals
          , body = defBody
          }
    )
    |= name
    |. sps
    |= (optional <|
      succeed Tuple.pair
        |= params
        |= retSize
      )
    |. sps
    |. token (Token "=" ExpectingEqual)
    |. sps
    |= optional locals
    |. sps
    |= expr


locals : HdlParser (List Def)
locals =
  succeed (\ds ->
    let
      _ = Debug.log "AL -> ds" <| ds
    in
    ds
  )
    |. keyword (Token "let" ExpectingLet)
    |. sps
    |= lazy (\_ -> defs)
    |. sps
    |. keyword (Token "in" ExpectingIn)


expr : HdlParser Expr
expr =
  oneOf
    [ bindingOrCall
    ]


bindingOrCall : HdlParser Expr
bindingOrCall =
  succeed
    (\callee args ->
      let
        _ = Debug.log "AL -> callee" <| callee
        _ = Debug.log "AL -> args" <| args
      in
      case args of
        Nothing ->
          Binding callee
        Just argList ->
          Call callee argList
    )
    |= name
    |. sps
    |= (optional <|
      loop [] <| \revNames ->
        let
          _ = Debug.log "AL -> revNames" <| revNames
        in
        oneOf
          [ succeed (\n -> Loop (n :: revNames))
            |= name
            |. sps
          , succeed ()
            |> map (\_ -> Done (List.reverse revNames))
          ]
    )


optional : HdlParser a -> HdlParser (Maybe a)
optional parser =
  oneOf
    [ parser |> map Just
    , succeed Nothing
    ]


retSize : HdlParser Int
retSize =
  succeed identity
    |. token (Token "->" ExpectingArrow)
    |. sps
    |. token (Token "[" ExpectingLeftBracket)
    |. sps
    |= int ExpectingInt InvalidNumber
    |. sps
    |. token (Token "]" ExpectingRightBracket)


params : HdlParser (List Param)
params =
  loop [] <| \revParams -> oneOf
    [ succeed (\p -> Loop (p :: revParams))
      |= (
        succeed Param
          |= name
          |. token (Token "[" ExpectingLeftBracket)
          |. sps
          |= int ExpectingInt InvalidNumber
          |. sps
          |. token (Token "]" ExpectingRightBracket)
      )
      |. sps
    , succeed ()
        |> map (\_ -> Done (List.reverse revParams))
    ]


name : HdlParser String
name =
  variable
    { start = Char.isLower
    , inner = \c -> Char.isAlphaNum c || c == '_'
    , reserved = reserved
    , expecting = ExpectingName
    }


sps : HdlParser ()
sps =
  loop 0 <| ifProgress <|
    oneOf
      [ lineComment (Token "--" ExpectingStartOfLineComment)
      , multiComment (Token "{-" ExpectingStartOfMultiLineComment) (Token "-}" ExpectingEndOfMultiLineComment) Nestable
      , spaces
      ]


ifProgress : HdlParser a -> Int -> HdlParser (Step Int ())
ifProgress parser offset =
  succeed identity
    |. parser
    |= getOffset
    |> map (\newOffset -> if offset == newOffset then Done () else Loop newOffset)
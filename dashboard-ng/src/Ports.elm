port module Ports exposing (getTextareaValue, mkEditor, rmEditor, lastItemVisible)

import Json.Encode exposing (Value)


port mkEditor : Maybe String -> Cmd msg


port rmEditor : Maybe String -> Cmd msg


port getTextareaValue : (Value -> msg) -> Sub msg


port lastItemVisible : (() -> msg) -> Sub msg

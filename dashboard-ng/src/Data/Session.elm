module Data.Session exposing (..)

import Data.User exposing (User)


type alias Session =
    { user : Maybe User }

module Request.User exposing (get)

import Json.Decode as Decode
import Data.User as User
import Http


get : Http.Request User.User
get =
    Http.get "/api/user" (Decode.field "user" User.decoder)

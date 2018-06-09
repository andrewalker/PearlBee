module Data.User exposing (User, decoder)

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (decode, required)


type alias User =
    { username : String
    , name : Maybe String
    , verifiedByPeers : Bool
    , verifiedEmail : Bool
    }


decoder : Decoder User
decoder =
    decode User
        |> required "username" Decode.string
        |> required "name" (Decode.nullable Decode.string)
        |> required "verified_by_peers" Decode.bool
        |> required "verified_email" Decode.bool

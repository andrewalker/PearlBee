module Data.Post exposing (..)

import UrlParser as Url
import Json.Decode as Decode exposing (int, string, Decoder)
import Json.Decode.Pipeline exposing (decode, required)


type Slug
    = Slug String


slugParser : Url.Parser (Slug -> a) a
slugParser =
    Url.custom "SLUG" (Ok << Slug)


slugToString : Slug -> String
slugToString (Slug slug) =
    slug


type alias Post =
    { slug : Slug
    , id : Int
    , title : String
    , content : String
    , abstract : String
    , tags : List String
    , date : String
    }


decoder : Decoder Post
decoder =
    decode Post
        |> Json.Decode.Pipeline.required "slug" (Decode.map Slug string)
        |> Json.Decode.Pipeline.required "id" int
        |> Json.Decode.Pipeline.required "title" string
        |> Json.Decode.Pipeline.required "content" string
        |> Json.Decode.Pipeline.required "abstract" string
        |> Json.Decode.Pipeline.required "tags" (Decode.list string)
        |> Json.Decode.Pipeline.required "date" string

module Route exposing (Route(..), fromLocation, href, modifyUrl)

import Html exposing (Attribute)
import Html.Attributes as Attr
import Navigation exposing (Location)
import UrlParser as Url exposing ((</>), Parser, oneOf, parseHash, s, string)
import Data.Post exposing (slugParser, slugToString, Slug)


-- ROUTING --


type Route
    = Posts
    | Settings
    | NewPost
    | EditPost Slug


route : Parser (Route -> a) a
route =
    oneOf
        [ Url.map Posts (s "")
        , Url.map Settings (s "settings")
        , Url.map NewPost (s "new")
        , Url.map EditPost (s "edit" </> slugParser)
        ]



-- INTERNAL --


routeToString : Route -> String
routeToString page =
    let
        pieces =
            case page of
                Posts ->
                    []

                Settings ->
                    [ "settings" ]

                NewPost ->
                    [ "new" ]

                EditPost slug ->
                    [ "edit", slugToString slug ]
    in
        "#/" ++ String.join "/" pieces



-- PUBLIC HELPERS --


href : Route -> Attribute msg
href route =
    Attr.href (routeToString route)


modifyUrl : Route -> Cmd msg
modifyUrl =
    routeToString >> Navigation.modifyUrl


fromLocation : Location -> Maybe Route
fromLocation location =
    if String.isEmpty location.hash then
        Just Posts
    else
        parseHash route location

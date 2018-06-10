module Page.Posts.Editor exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Data.Session exposing (Session)
import Data.Post exposing (Post, Slug, slugToString)
import Json.Decode as Json
import Ports exposing (rmEditor, mkEditor)
import Feather
import Debug
import Json.Decode as Decode exposing (int, string, Decoder)
import Json.Decode.Pipeline exposing (decode, required)
import Page.Errored exposing (PageLoadError, pageLoadError)
import Task exposing (Task)
import Http
import Char
import Views.Page as Page


-- MODEL


type alias Model =
    Post


initNew : Model
initNew =
    { id = 0
    , title = ""
    , content = ""
    , slug = Data.Post.Slug ""
    , tags = []
    , abstract = ""
    , date = "just now"
    }


initEdit : Int -> Task PageLoadError Model
initEdit id =
    getPost id
        |> Http.toTask
        |> Task.mapError (\_ -> pageLoadError Page.Other "Article is currently unavailable.")
        |> Task.map (\post -> post)


getPost : Int -> Http.Request Post
getPost id =
    Http.get ("/api/post/" ++ toString id) (Decode.field "post" Data.Post.decoder)



-- UPDATE


type Msg
    = SetTitle String
    | SetContent String
    | SetAbstract String
    | SetTags String
    | SetSlug String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SetTitle t ->
            ( { model | title = t }, Cmd.none )

        SetContent c ->
            ( { model | content = c }, Cmd.none )

        SetAbstract e ->
            ( { model | abstract = e }, Cmd.none )

        SetSlug s ->
            ( { model | slug = Data.Post.Slug s }, Cmd.none )

        -- XXX: Make this robust:
        SetTags t ->
            ( { model | tags = (String.split "," t) }, Cmd.none )


tagsToString : List String -> String
tagsToString t =
    String.join "," t


slugFromTitle : String -> Slug
slugFromTitle s =
    Data.Post.Slug (sluggifyTitle s)


sluggifyTitle : String -> String
sluggifyTitle s =
    String.foldr (replaceNonAlpha >> String.cons) "" (String.toLower s)


replaceNonAlpha : Char -> Char
replaceNonAlpha c =
    if Char.isLower c || Char.isUpper c || Char.isDigit c then
        c
    else
        '-'



-- VIEW


view : Session -> Model -> Html Msg
view session model =
    div [ class "col mt-5 px-2" ]
        [ div [ class "float-right mr-3" ]
            [ div [ class "btn-group dropdown" ]
                [ button [ class "btn-more", type_ "button", id "dropdownMenuButton", attribute "data-toggle" "dropdown" ]
                    [ Feather.settings "#000000" 15 ]
                , div [ class "dropdown-menu dropdown-menu-right", attribute "aria-labelledby" "dropdownMenuButton", style [ ( "width", "40rem" ) ] ]
                    [ Html.form [ class "px-4 py-3" ]
                        [ div [ class "form-group" ]
                            [ label [] [ text "Post URL:" ]
                            , input [ type_ "text", class "form-control", placeholder (sluggifyTitle model.title), onInput SetSlug, value (slugToString model.slug) ] []
                            ]
                        , div [ class "form-group" ]
                            [ label [] [ text "Tags, comma-separated:" ]
                            , input [ type_ "text", class "form-control", placeholder "e.g. perl, programming, free software", onInput SetTags, value (tagsToString model.tags) ] []
                            ]
                        , div [ class "form-group" ]
                            [ label [] [ text "Abstract" ]
                            , textarea [ class "form-control", placeholder "Short summary...", onInput SetAbstract, value model.abstract ] []
                            ]
                        ]
                    ]
                ]
            ]
        , div [ class "mx-3" ]
            [ input [ class "h1 input-like-h1", onInput SetTitle, value model.title, placeholder "Title" ] []
            , br [] []
            , textarea [ id "mdEditor", class "form-control", onInput SetContent, value model.content ] []
            , button [ class "btn btn-primary", type_ "button" ]
                [ Feather.eye "#ffffff" 13, text " Publish" ]
            , text " "
            , button [ class "btn btn-secondary", type_ "button" ]
                [ Feather.edit "#ffffff" 13, text " Draft" ]
            , button [ class "btn btn-danger pull-right", type_ "button" ]
                [ Feather.trash "#ffffff" 13, text " Trash" ]
            , br [] []
            , br [] []
            ]
        ]


targetTitleContent : Json.Decoder String
targetTitleContent =
    Json.at [ "target", "textContent" ] Json.string

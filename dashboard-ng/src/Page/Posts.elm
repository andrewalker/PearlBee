module Page.Posts exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Data.Session exposing (Session)
import Json.Decode as Decode exposing (int, string, Decoder)
import Json.Decode.Pipeline exposing (decode, required)
import Page.Errored exposing (PageLoadError, pageLoadError)
import Task exposing (Task)
import Views.Page as Page
import Time exposing (Time)
import Data.Post exposing (Post)
import Route
import Process
import Http


-- MODEL


type PostSorting
    = DateAsc
    | DateDesc


type GetPostsStatus
    = Unattempted
    | Loading
    | GotOk
    | GotError String


type alias Model =
    { posts : List Post
    , status : GetPostsStatus
    }


init : Task PageLoadError Model
init =
    let
        loadPosts =
            getPosts_
                |> Http.toTask

        handleLoadError _ =
            pageLoadError Page.Posts "Posts are currently unavailable."
    in
        Task.map2 Model loadPosts (Task.succeed GotOk)
            |> Task.mapError handleLoadError



-- UPDATE


type Msg
    = Sort PostSorting
    | LastItemVisible
    | GetPosts
    | GetMorePosts
    | GotPosts (Result Http.Error (List Post))
    | GotMorePosts (Result Http.Error (List Post))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GetPosts ->
            ( model, getPosts )

        GetMorePosts ->
            ( model, getMorePosts )

        LastItemVisible ->
            ( { model | status = Loading }
            , if model.status == Loading then
                Cmd.none
              else
                delay (Time.second * 5) <| GetMorePosts
            )

        GotMorePosts (Ok newPosts) ->
            ( { model | posts = (List.append model.posts newPosts), status = GotOk }, Cmd.none )

        GotMorePosts (Err (Http.BadPayload msg _)) ->
            ( { model | status = GotError msg }, Cmd.none )

        GotMorePosts (Err _) ->
            ( { model | status = GotError "there is something off with the request" }, Cmd.none )

        GotPosts (Ok newPosts) ->
            ( { model | posts = newPosts, status = GotOk }, Cmd.none )

        GotPosts (Err (Http.BadPayload msg _)) ->
            ( { model | status = GotError msg, posts = [] }, Cmd.none )

        GotPosts (Err _) ->
            ( { model | status = GotError "there is something off with the request", posts = [] }, Cmd.none )

        Sort DateAsc ->
            ( { model | posts = List.sortBy .id model.posts }, Cmd.none )

        Sort DateDesc ->
            ( { model | posts = List.sortBy .id model.posts |> List.reverse }, Cmd.none )


delay : Time.Time -> msg -> Cmd msg
delay time msg =
    Process.sleep time
        |> Task.perform (\_ -> msg)


getPosts : Cmd Msg
getPosts =
    let
        url =
            "/api/user/posts"

        request =
            Http.get url (Decode.field "posts" (Decode.list Data.Post.decoder))
    in
        Http.send GotPosts request


getMorePosts : Cmd Msg
getMorePosts =
    let
        url =
            "/api/user/posts"

        request =
            Http.get url (Decode.field "posts" (Decode.list Data.Post.decoder))
    in
        Http.send GotMorePosts request


getPosts_ : Http.Request (List Post)
getPosts_ =
    Http.get "/api/user/posts" (Decode.field "posts" (Decode.list Data.Post.decoder))



-- VIEW


view : Session -> Model -> Html Msg
view session model =
    div [ class "col mt-5 px-2" ]
        [ div [ class "dropdown float-right mr-3" ]
            [ button [ class "btn btn-secondary dropdown-toggle", type_ "button", id "dropdownMenuButton", attribute "data-toggle" "dropdown" ]
                [ text "Sort by" ]
            , div [ class "dropdown-menu dropdown-menu-right", attribute "aria-labelledby" "dropdownMenuButton" ]
                [ a [ class "dropdown-item", href "javascript:void(0)", onClick (Sort DateAsc) ] [ text "Oldest first" ]
                , a [ class "dropdown-item", href "javascript:void(0)", onClick (Sort DateDesc) ] [ text "Newest first" ]
                ]
            ]
        , h1 [ class "ml-4" ] [ text "Posts" ]
        , viewStatus model.status
        , div [ class "list-group list-group-flush ml-1 list-posts" ]
            (List.map
                viewPost
                model.posts
            )
        , if model.status == Loading then
            p [ class "text-center m-5" ]
                [ img [ src "/dashboard-ng/images/spinner.svg", style [ ( "height", "25px" ), ( "width", "25px" ) ] ] []
                ]
          else
            text ""
        ]


viewStatus : GetPostsStatus -> Html Msg
viewStatus status =
    case status of
        Unattempted ->
            text ""

        Loading ->
            text ""

        GotOk ->
            text ""

        GotError msg ->
            h3 [] [ text ("Sorry! " ++ msg) ]


viewPost : Post -> Html Msg
viewPost post =
    a [ Route.href (Route.EditPost post.slug), class "list-group-item list-group-item-action" ]
        [ div [ class "d-flex justify-content-between" ]
            [ h5 [] [ text post.title ]
            , small [] [ em [ class "text-muted" ] [ text post.date ] ]
            ]
        , p [] [ text post.content ]
        ]

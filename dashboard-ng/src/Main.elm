module Main exposing (main)

import Html exposing (..)
import Navigation exposing (Location)
import Page.Posts as Posts
import Page.Posts.Editor as Editor
import Page.Errored as Errored exposing (PageLoadError)
import Data.Session exposing (Session)
import Data.User exposing (User)
import Data.Post exposing (Slug)
import Request.User as RU
import Http
import Task
import Views.Page as Page exposing (ActivePage)
import Ports exposing (mkEditor, rmEditor)


-- import Page.Settings as Settings

import Route exposing (Route)
import Views.Page as Page


type Page
    = Blank
    | NotFound
    | Errored PageLoadError
    | Posts Posts.Model
    | Editor (Maybe Slug) Editor.Model


type PageState
    = Loaded Page
    | TransitioningFrom Page



-- MODEL --


type alias Model =
    { session : Session
    , pageState : PageState
    }


init : Location -> ( Model, Cmd Msg )
init location =
    let
        ( m1, c1 ) =
            setRoute (Route.fromLocation location)
                { pageState = Loaded initialPage
                , session = { user = Nothing }
                }
    in
        ( m1, Cmd.batch [ (Http.send UserSessionLoaded RU.get), c1 ] )


initialPage : Page
initialPage =
    Blank



-- VIEW --


view : Model -> Html Msg
view model =
    case model.pageState of
        Loaded page ->
            viewPageIfLoggedIn model.session False page

        TransitioningFrom page ->
            viewPageIfLoggedIn model.session True page


viewPageIfLoggedIn : Session -> Bool -> Page -> Html Msg
viewPageIfLoggedIn session isLoading page =
    case session.user of
        Nothing ->
            Html.text "No session"
                |> Page.frame isLoading session Page.Other

        Just _ ->
            viewPage session isLoading page


viewPage : Session -> Bool -> Page -> Html Msg
viewPage session isLoading page =
    let
        frame =
            Page.frame isLoading session
    in
        case page of
            Blank ->
                -- This is for the very initial page load, while we are loading
                -- data via HTTP. We could also render a spinner here.
                Html.text ""
                    |> frame Page.Other

            NotFound ->
                Html.text "Not Found!"
                    |> frame Page.Other

            Errored subModel ->
                Errored.view subModel
                    |> frame Page.Posts

            Posts subModel ->
                Posts.view session subModel
                    |> frame Page.Posts
                    |> Html.map PostsMsg

            Editor maybeSlug subModel ->
                let
                    framePage =
                        case maybeSlug of
                            Nothing ->
                                Page.NewPost

                            Just slug ->
                                Page.EditPost slug
                in
                    Editor.view session subModel
                        |> frame framePage
                        |> Html.map EditorMsg



--
--           Settings subModel ->
--               Settings.view subModel
--                   |> frame Page.Other
--                   |> Html.map SettingsMsg
--


getPage : PageState -> Page
getPage pageState =
    case pageState of
        Loaded page ->
            page

        TransitioningFrom page ->
            page



-- UPDATE --


type Msg
    = SetRoute (Maybe Route)
    | UserSessionLoaded (Result Http.Error User)
    | PostsLoaded (Result PageLoadError Posts.Model)
    | EditPostLoaded Slug (Result PageLoadError Editor.Model)
    | PostsMsg Posts.Msg
    | EditorMsg Editor.Msg


setRoute : Maybe Route -> Model -> ( Model, Cmd Msg )
setRoute maybeRoute model =
    let
        transition toMsg task =
            ( { model | pageState = TransitioningFrom (getPage model.pageState) }
            , Cmd.batch [ rmEditor (Just "mdEditor"), Task.attempt toMsg task ]
            )

        errored =
            pageErrored model
    in
        case maybeRoute of
            Nothing ->
                ( { model | pageState = Loaded Blank }, Cmd.none )

            Just Route.Posts ->
                transition PostsLoaded Posts.init

            Just Route.NewPost ->
                ( { model | pageState = Loaded (Editor Nothing Editor.initNew) }, mkEditor (Just "mdEditor") )

            Just (Route.EditPost slug) ->
                ( { model | pageState = TransitioningFrom (getPage model.pageState) }
                , Cmd.batch [ mkEditor (Just "mdEditor"), Task.attempt (EditPostLoaded slug) (Editor.initEdit slug) ]
                )

            _ ->
                ( { model | pageState = Loaded Blank }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    updatePage (getPage model.pageState) msg model


updatePage : Page -> Msg -> Model -> ( Model, Cmd Msg )
updatePage page msg model =
    let
        toPage toModel toMsg subUpdate subMsg subModel =
            let
                ( newModel, newCmd ) =
                    subUpdate subMsg subModel
            in
                ( { model | pageState = Loaded (toModel newModel) }, Cmd.map toMsg newCmd )
    in
        case ( msg, page ) of
            ( UserSessionLoaded (Ok u), _ ) ->
                ( { model | session = { user = Just u } }, Cmd.none )

            ( UserSessionLoaded (Err _), _ ) ->
                ( { model | session = { user = Nothing } }, Cmd.none )

            ( SetRoute route, _ ) ->
                setRoute route model

            ( PostsLoaded (Ok subModel), _ ) ->
                ( { model | pageState = Loaded (Posts subModel) }, Cmd.none )

            ( PostsLoaded (Err error), _ ) ->
                ( { model | pageState = Loaded (Errored error) }, Cmd.none )

            ( EditPostLoaded slug (Ok subModel), _ ) ->
                ( { model | pageState = Loaded (Editor (Just slug) subModel) }, Cmd.none )

            ( EditPostLoaded _ (Err error), _ ) ->
                ( { model | pageState = Loaded (Errored error) }, Cmd.none )

            ( PostsMsg subMsg, Posts subModel ) ->
                toPage Posts PostsMsg Posts.update subMsg subModel

            ( EditorMsg subMsg, Editor slug subModel ) ->
                toPage (Editor slug) EditorMsg Editor.update subMsg subModel

            ( _, NotFound ) ->
                -- Disregard incoming messages that arrived from NotFound page
                ( model, Cmd.none )

            ( _, _ ) ->
                -- Disregard incoming messages that arrived for the wrong page
                ( model, Cmd.none )


pageErrored : Model -> ActivePage -> String -> ( Model, Cmd msg )
pageErrored model activePage errorMessage =
    let
        error =
            Errored.pageLoadError activePage errorMessage
    in
        ( { model | pageState = Loaded (Errored error) }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ pageSubscriptions (getPage model.pageState)
        ]


pageSubscriptions : Page -> Sub Msg
pageSubscriptions page =
    case page of
        Posts model ->
            let
                lastItemVisibleToMsg () =
                    PostsMsg (Posts.LastItemVisible)
            in
                Ports.lastItemVisible lastItemVisibleToMsg

        _ ->
            Sub.none



-- MAIN --


main : Program Never Model Msg
main =
    Navigation.program (Route.fromLocation >> SetRoute)
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

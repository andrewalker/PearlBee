module Views.Page exposing (ActivePage(..), frame)

{-| The frame around a typical page - that is, the header and footer.
-}

import Html exposing (..)
import Html.Attributes exposing (..)
import Route exposing (Route)
import Data.Session exposing (Session)
import Data.User exposing (User)
import Data.Post exposing (Slug)
import Feather


{-| Determines which navbar link (if any) will be rendered as active.

Note that we don't enumerate every page here, because the navbar doesn't
have links for every page. Anything that's not part of the navbar falls
under Other.

-}
type ActivePage
    = Other
    | Settings
    | NewPost
    | EditPost Int
    | Posts


isUserConfirmed : Maybe User -> Bool
isUserConfirmed u =
    Maybe.withDefault False (Maybe.map .verifiedByPeers u)


frame : Bool -> Session -> ActivePage -> Html msg -> Html msg
frame _ session activePage content =
    div []
        [ div [ class "sidebar bg-light" ]
            [ div [ class "sidebar-container" ]
                [ div [ class "media my-5 px-4" ]
                    [ img
                        [ class "align-self-center m-2"
                        , style [ ( "width", "75px" ), ( "height", "75px" ) ]
                        , src "/dashboard-ng/images/camel-silhouette.png"
                        ]
                        []
                    , div [ class "media-body" ]
                        [ h2 [] [ text "blogs.perl.org" ]
                        , p [ class "mb-0" ]
                            [ text "There's more than one way to blog it." ]
                        ]
                    ]
                , ul
                    [ class "nav flex-column mt-5" ]
                    [ navbarLink activePage Route.NewPost [ text "Compose" ]
                    , navbarLink activePage Route.Posts [ text "Posts" ]
                    , if isUserConfirmed session.user then
                        li [ class "nav-item" ] [ a [ class "nav-link text-dark", href "#confirm-authors" ] [ text "Confirm new authors" ] ]
                      else
                        text ""
                    ]
                ]
            , case session.user of
                Nothing ->
                    text ""

                Just u ->
                    renderUserInfo u
            ]
        , content
        ]


renderUserInfo : User -> Html msg
renderUserInfo u =
    footer [ class "sidebar-footer" ]
        [ div [ class "media p-3" ]
            [ img
                [ class "m-3 rounded-circle"
                , alt "75x75"
                , style [ ( "width", "75px" ), ( "height", "75px" ) ]
                , src "data:image/svg+xml;charset=UTF-8,%3Csvg%20width%3D%2275%22%20height%3D%2275%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%2075%2075%22%20preserveAspectRatio%3D%22none%22%3E%3Cdefs%3E%3Cstyle%20type%3D%22text%2Fcss%22%3E%23holder_1618081da66%20text%20%7B%20fill%3Argba(255%2C255%2C255%2C.75)%3Bfont-weight%3Anormal%3Bfont-family%3AHelvetica%2C%20monospace%3Bfont-size%3A10pt%20%7D%20%3C%2Fstyle%3E%3C%2Fdefs%3E%3Cg%20id%3D%22holder_1618081da66%22%3E%3Crect%20width%3D%2275%22%20height%3D%2275%22%20fill%3D%22%23777%22%3E%3C%2Frect%3E%3Cg%3E%3Ctext%20x%3D%2220%22%20y%3D%2241.7%22%3E75x75%3C%2Ftext%3E%3C%2Fg%3E%3C%2Fg%3E%3C%2Fsvg%3E"
                ]
                []
            , div [ class "align-self-center media-body" ]
                [ h5 [ class "mt-0" ] [ text u.username ]
                , p [ class "mb-0" ]
                    [ text "Author"
                    , if not u.verifiedByPeers then
                        em [ class "text-muted" ] [ text " (unconfirmed)" ]
                      else
                        text ""
                    , br [] []
                    , a [ href "#" ] [ text "Settings" ]
                    , text " | "
                    , a [ href "/logout" ] [ text "Logout" ]
                    ]
                ]
            ]
        ]


navbarLink : ActivePage -> Route -> List (Html msg) -> Html msg
navbarLink page route linkContent =
    li [ classList [ ( "nav-item", True ), ( "active", isActive page route ) ] ]
        [ a [ class "nav-link text-dark", Route.href route ]
            (if isActive page route then
                List.append [ Feather.chevronsRight "#343a40" 12, text " " ] linkContent
             else
                linkContent
            )
        ]


isActive : ActivePage -> Route -> Bool
isActive page route =
    case ( page, route ) of
        ( NewPost, Route.NewPost ) ->
            True

        ( EditPost _, Route.EditPost _ ) ->
            True

        ( Posts, Route.Posts ) ->
            True

        _ ->
            False

module Reorderable
    exposing
        ( ul
        , ol
        , div
        , State
        , initialState
        , Msg
        , update
        , Config
        , HtmlWrapper
        , simpleConfig
        , fullConfig
        , Event(..)
        )

{-| This library helps you create drag and drop re-orderable html lists

Check out the [examples][] to see how it works
[examples]: https://github.com/rohanorton/elm-reorderable-list/tree/master/examples

# View
@docs ul, ol, div

# Config
@docs Config, HtmlWrapper, simpleConfig, fullConfig

# State
@docs State, initialState

# Updates
@docs Msg, update, Event

-}

import Html exposing (text, Html, Attribute)
import Html.Keyed as Keyed
import Html.Attributes exposing (draggable, class)
import Html.Events exposing (on, onWithOptions)
import Json.Decode as Json
import Reorderable.Helpers as Helpers


-- MODEL


{-| Internal state of the re-orderable component.

Tracks which element is being dragged and whether mouse is over an ignored
element.
-}
type State
    = State
        { dragging : Maybe String
        , mouseOverIgnored : Bool
        }


{-| Create the inital state for your re-orderable component.
-}
initialState : State
initialState =
    State
        { dragging = Nothing
        , mouseOverIgnored = False
        }



-- UPDATE


{-| Messages sent to internal update command used for updating the internal
component state.
-}
type Msg
    = MouseOverIgnored Bool
    | StartDragging String
    | StopDragging


{-|
-}
type Event
    = DragStart String
    | DragEnd


{-| Update function for updating the state of the component.
-}
update : Msg -> State -> ( State, Maybe Event )
update msg (State state) =
    case msg of
        MouseOverIgnored mouseOverIgnored ->
            ( State { state | mouseOverIgnored = mouseOverIgnored }
            , Nothing
            )

        StartDragging id ->
            let
                dragging =
                    if state.mouseOverIgnored then
                        Nothing
                    else
                        Just id
            in
                ( State { state | dragging = dragging }
                , Just <| DragStart id
                )

        StopDragging ->
            ( State { state | dragging = Nothing }
            , Just DragEnd
            )



-- VIEW


{-| Takes a list and turn it into an html, drag and drop re-orderable
ordered-list. `Config` is configuration for the component, describing how the
data should be displayed and how to handle events.

**Note:** `State` and `List data` belong in your `Model`. `Config` belongs in
your view.
-}
ol : Config data msg -> State -> List data -> Html msg
ol ((Config { listClass }) as config) state list =
    Keyed.ol [ class listClass ] <| List.map (childView Html.li config list state) list


{-| Takes a list and turn it into an html, drag and drop re-orderable
unordered-list. `Config` is configuration for the component, describing how the
data should be displayed and how to handle events.

**Note:** `State` and `List data` belong in your `Model`. `Config` belongs in
your view.
-}
ul : Config data msg -> State -> List data -> Html msg
ul ((Config { listClass }) as config) state list =
    Keyed.ul [ class listClass ] <| List.map (childView Html.li config list state) list


{-| Takes a list and turn it into an html, drag and drop re-orderable
divs. `Config` is configuration for the component, describing how the
data should be displayed and how to handle events.

**Note:** `State` and `List data` belong in your `Model`. `Config` belongs in
your view.
-}
div : Config data msg -> State -> List data -> Html msg
div ((Config { listClass }) as config) state list =
    Keyed.node "div" [ class listClass ] <| List.map (childView Html.div config list state) list


type alias HtmlElement msg =
    List (Attribute msg) -> List (Html msg) -> Html msg


childView : HtmlElement msg -> Config data msg -> List data -> State -> data -> ( String, Html msg )
childView element (Config config) list (State state) data =
    let
        id =
            config.toId data

        ( childView, childClass ) =
            if state.dragging == Just id then
                ( config.placeholderView data, config.placeholderClass )
            else
                ( config.itemView (ignoreDrag config.toMsg) data, config.itemClass )
    in
        ( id
        , element
            [ draggable <| toString config.draggable
            , onDragStart state.mouseOverIgnored <| config.toMsg (StartDragging id)
            , onDragEnd <| config.toMsg StopDragging
            , onDragEnter config.updateList (\() -> Helpers.updateList config.toId id state.dragging list)
            , class childClass
            ]
            [ childView ]
        )


onDragStart : Bool -> msg -> Attribute msg
onDragStart ignored msg =
    onWithOptions "dragstart"
        { stopPropagation = ignored
        , preventDefault = ignored
        }
    <|
        Json.succeed msg


onDragEnd : msg -> Attribute msg
onDragEnd msg =
    on "dragend" <| Json.succeed msg


onDragEnter : (List a -> msg) -> (() -> List a) -> Attribute msg
onDragEnter updateList listThunk =
    (Json.succeed ())
        |> Json.andThen (Json.succeed << updateList << listThunk)
        |> on "dragenter"


ignoreDrag : (Msg -> msg) -> HtmlWrapper msg
ignoreDrag toMsg elem attr children =
    elem
        (attr
            ++ [ on "mouseenter" <| Json.succeed <| toMsg <| MouseOverIgnored True
               , on "mouseleave" <| Json.succeed <| toMsg <| MouseOverIgnored False
               ]
        )
        children



-- CONFIG


{-| Configuration for your re-orderable list.

**Note:** Your `Config` should *never* be held in your model.
It should only appear in `view` code.
-}
type Config data msg
    = Config
        { toId : data -> String
        , toMsg : Msg -> msg
        , itemView : HtmlWrapper msg -> data -> Html msg
        , placeholderView : data -> Html msg
        , listClass : String
        , itemClass : String
        , placeholderClass : String
        , draggable : Bool
        , updateList : List data -> msg
        }


{-| This type alias is to simplify the definition of a function that takes a
standard html function and its arguments to return a Html msg

This doesn't make much sense in the abstract, check out the ignoreDrag function
for an example
-}
type alias HtmlWrapper msg =
    (List (Attribute msg) -> List (Html msg) -> Html msg)
    -> List (Attribute msg)
    -> List (Html msg)
    -> Html msg


{-| A really really simple re-orderable list.

For creating a basic reorderable ul or ol from a list of strings. It's
painfully simple and probably a bit useless!

-}
simpleConfig : { toMsg : Msg -> msg, updateList : List String -> msg } -> Config String msg
simpleConfig { toMsg, updateList } =
    Config
        { toId = identity
        , toMsg = toMsg
        , itemView = always text
        , listClass = ""
        , itemClass = ""
        , placeholderClass = ""
        , placeholderView = text
        , draggable = True
        , updateList = updateList
        }


{-| Provides all the bells and whistles that this library has to offer at this
time.

- toId: Converts your data into an ID string. This *must* be a unique ID for
    the component to work effectively!

-}
fullConfig :
    { toId : data -> String
    , toMsg : Msg -> msg
    , itemView : HtmlWrapper msg -> data -> Html msg
    , placeholderView : data -> Html msg
    , listClass : String
    , itemClass : String
    , placeholderClass : String
    , draggable : Bool
    , updateList : List data -> msg
    }
    -> Config data msg
fullConfig =
    Config

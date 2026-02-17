module BundleGraph exposing (main)

import Browser
import Dict
import Html exposing (Html, button, div, h1, text)
import Html.Attributes exposing (disabled, style)
import Html.Events exposing (onClick)
import Json.Decode as Decode exposing (Decoder)
import Sankey exposing (layout, render)


type alias Model =
    { bundles : List Bundle
    , selectedNodeId : Maybe String
    , lockedNodeIds : List String
    , width : Maybe Int
    , height : Maybe Int
    }


type alias Bundle =
    { name : String
    , elmApps : List String
    , templates : List String
    }


type alias Flags =
    { bundles : List Bundle
    , width : Maybe Int
    , height : Maybe Int
    }


type alias LabelNode =
    { id : String
    , label : String
    , column : Int
    }


type Msg
    = SelectNode String
    | DeselectNode
    | ToggleLockNode String
    | ClearSelection


main : Program Decode.Value Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


init : Decode.Value -> ( Model, Cmd Msg )
init flags =
    case Decode.decodeValue flagsDecoder flags of
        Ok decoded ->
            ( { bundles = decoded.bundles
              , selectedNodeId = Nothing
              , lockedNodeIds = []
              , width = decoded.width
              , height = decoded.height
              }
            , Cmd.none
            )

        Err _ ->
            ( { bundles = []
              , selectedNodeId = Nothing
              , lockedNodeIds = []
              , width = Nothing
              , height = Nothing
              }
            , Cmd.none
            )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectNode appId ->
            ( { model | selectedNodeId = Just appId }, Cmd.none )

        DeselectNode ->
            case model.selectedNodeId of
                Just nodeId ->
                    if List.member nodeId model.lockedNodeIds then
                        ( model, Cmd.none )

                    else
                        ( { model | selectedNodeId = Nothing }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        ToggleLockNode nodeId ->
            if List.member nodeId model.lockedNodeIds then
                ( { model
                    | lockedNodeIds = List.filter (\id -> id /= nodeId) model.lockedNodeIds
                  }
                , Cmd.none
                )

            else
                ( { model | lockedNodeIds = nodeId :: model.lockedNodeIds }
                , Cmd.none
                )

        ClearSelection ->
            ( { model | selectedNodeId = Nothing, lockedNodeIds = [] }, Cmd.none )


view : Model -> Html Msg
view model =
    let
        nodes =
            buildNodes model.bundles

        columnWidths =
            buildColumnWidths nodes

        highlightedNodeIds =
            case model.selectedNodeId of
                Just id ->
                    id :: model.lockedNodeIds

                Nothing ->
                    model.lockedNodeIds

        sankeyModel =
            { svgWidth = toFloat (Maybe.withDefault 1100 model.width)
            , svgHeight = toFloat (Maybe.withDefault (totalHeightInt model.bundles) model.height)
            , columnWidths = columnWidths
            , nodePadding = 8
            , columnSpacing = 350
            , edgeColor = "#60A5FA"
            , edgeOpacity = 0.3
            , fontSize = 11
            , highlightedNodeIds = highlightedNodeIds
            , lockedNodeIds = model.lockedNodeIds
            }

        events =
            { onSelectNode = SelectNode
            , onDeselectNode = DeselectNode
            , onLockNode = ToggleLockNode
            }

        diagram =
            layout sankeyModel nodes (buildEdges model.bundles)

        hasSelection =
            not (List.isEmpty model.lockedNodeIds)

        buttonStyles =
            if hasSelection then
                [ style "color" "#6b7280"
                , style "cursor" "pointer"
                , style "border" "1px solid #374151"
                ]

            else
                [ style "color" "#9ca3af"
                , style "cursor" "not-allowed"
                , style "border" "1px solid #d1d5db"
                ]
    in
    div [ Html.Attributes.class "bundle-graph" ]
        [ div [ style "display" "flex", style "align-items" "center", style "gap" "16px" ]
            [ h1
                [ style "font-family" "system-ui, sans-serif"
                , style "margin-bottom" "10px"
                , style "color" "#374151"
                ]
                [ text "Antoinette Bundle Graph" ]
            , button
                ([ onClick ClearSelection
                 , style "font-size" "12px"
                 , style "margin-bottom" "8px"
                 , style "border-radius" "4px"
                 , style "padding" "4px 8px"
                 , style "background" "white"
                 , disabled (not hasSelection)
                 ]
                    ++ buttonStyles
                )
                [ text "Clear Selection" ]
            ]
        , render sankeyModel events diagram
        ]


totalHeightInt : List Bundle -> Int
totalHeightInt bundles =
    let
        elmApps =
            uniqueElmApps bundles

        templates =
            uniqueTemplates bundles

        maxItems =
            max (List.length elmApps) (max (List.length bundles) (List.length templates))

        rowHeight =
            27
    in
    maxItems * rowHeight + 100


buildColumnWidths : List LabelNode -> Dict.Dict Int Float
buildColumnWidths nodes =
    let
        padding =
            2

        labelWidth node =
            let
                perCharacter =
                    case node.column of
                        2 ->
                            6

                        _ ->
                            7
            in
            toFloat (padding + String.length node.label * perCharacter)

        updateMax node dict =
            let
                currentMax =
                    Dict.get node.column dict |> Maybe.withDefault 0

                nodeWidth =
                    labelWidth node
            in
            Dict.insert node.column (max currentMax nodeWidth) dict
    in
    List.foldl updateMax Dict.empty nodes


buildNodes : List Bundle -> List LabelNode
buildNodes bundles =
    let
        elmAppNodes =
            uniqueElmApps bundles
                |> List.map
                    (\app ->
                        { id = "app:" ++ app
                        , label = app
                        , column = 0
                        }
                    )

        bundleNodes =
            bundles
                |> List.map
                    (\bundle ->
                        { id = "bundle:" ++ bundle.name
                        , label = bundle.name
                        , column = 1
                        }
                    )

        templateNodes =
            uniqueTemplates bundles
                |> List.map
                    (\template ->
                        { id = "template:" ++ template
                        , label = template
                        , column = 2
                        }
                    )
    in
    elmAppNodes ++ bundleNodes ++ templateNodes


buildEdges : List Bundle -> List { fromId : String, toId : String }
buildEdges bundles =
    let
        appToBundleEdges =
            bundles
                |> List.concatMap
                    (\bundle ->
                        bundle.elmApps
                            |> List.map
                                (\app ->
                                    { fromId = "app:" ++ app
                                    , toId = "bundle:" ++ bundle.name
                                    }
                                )
                    )

        bundleToTemplateEdges =
            bundles
                |> List.concatMap
                    (\bundle ->
                        bundle.templates
                            |> List.map
                                (\template ->
                                    { fromId = "bundle:" ++ bundle.name
                                    , toId = "template:" ++ template
                                    }
                                )
                    )
    in
    appToBundleEdges ++ bundleToTemplateEdges


uniqueElmApps : List Bundle -> List String
uniqueElmApps bundles =
    bundles
        |> List.concatMap .elmApps
        |> List.sort
        |> unique


uniqueTemplates : List Bundle -> List String
uniqueTemplates bundles =
    bundles
        |> List.concatMap .templates
        |> List.sort
        |> unique


unique : List comparable -> List comparable
unique list =
    case list of
        [] ->
            []

        first :: rest ->
            first :: unique (List.filter (\x -> x /= first) rest)


flagsDecoder : Decoder Flags
flagsDecoder =
    Decode.map3 Flags
        (Decode.field "bundles" (Decode.list bundleDecoder))
        (Decode.maybe (Decode.field "width" Decode.int))
        (Decode.maybe (Decode.field "height" Decode.int))


bundleDecoder : Decoder Bundle
bundleDecoder =
    Decode.map3 Bundle
        (Decode.field "name" Decode.string)
        (Decode.field "elm_apps" (Decode.list Decode.string))
        (Decode.field "templates" (Decode.list Decode.string))

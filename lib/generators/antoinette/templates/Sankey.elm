module Sankey exposing
    ( Diagram
    , Edge
    , Model
    , Node
    , RenderEvents
    , defaults
    , layout
    , render
    )

import Dict exposing (Dict)
import Svg exposing (Svg, g, path, rect, svg, text, text_)
import Svg.Attributes
    exposing
        ( cursor
        , d
        , fill
        , fillOpacity
        , fontFamily
        , fontSize
        , height
        , rx
        , stroke
        , strokeOpacity
        , strokeWidth
        , textAnchor
        , viewBox
        , width
        , x
        , y
        )
import Svg.Events exposing (onClick, onMouseOut, onMouseOver)


type alias Model =
    { svgWidth : Float
    , svgHeight : Float
    , columnWidths : Dict Int Float
    , nodePadding : Float
    , columnSpacing : Float
    , edgeColor : String
    , edgeOpacity : Float
    , fontSize : Float
    , highlightedNodeIds : List String
    , lockedNodeIds : List String
    }


defaults : Model
defaults =
    { svgWidth = 1100
    , svgHeight = 800
    , columnWidths = Dict.empty
    , nodePadding = 10
    , columnSpacing = 300
    , edgeColor = "#999"
    , edgeOpacity = 0.4
    , fontSize = 12
    , highlightedNodeIds = []
    , lockedNodeIds = []
    }


type alias Node =
    { id : String
    , label : String
    , x : Float
    , y : Float
    , height : Float
    }


type alias Edge =
    { fromId : String
    , toId : String
    , fromX : Float
    , fromY : Float
    , toX : Float
    , toY : Float
    , thickness : Float
    }


type alias Diagram =
    { columns : Dict Int (List Node)
    , edges : List Edge
    }


type alias InputNode =
    { id : String
    , label : String
    , column : Int
    }


type alias InputEdge =
    { fromId : String
    , toId : String
    }


layout : Model -> List InputNode -> List InputEdge -> Diagram
layout model inputNodes inputEdges =
    let
        inputNodesByColumn =
            [ List.filter (\n -> n.column == 0) inputNodes
            , List.filter (\n -> n.column == 1) inputNodes
            , List.filter (\n -> n.column == 2) inputNodes
            ]

        nodeHeight =
            model.fontSize + 8

        columnWidth colIndex =
            Dict.get colIndex model.columnWidths |> Maybe.withDefault 100

        width0 =
            columnWidth 0

        width1 =
            columnWidth 1

        width2 =
            columnWidth 2

        gap =
            model.columnSpacing - (width0 + width1) / 2

        columnX col =
            case col of
                0 ->
                    0

                1 ->
                    width0 + gap

                _ ->
                    width0 + gap + width1 + gap

        breathingRoom =
            5

        positionColumn : Int -> List InputNode -> List Node
        positionColumn colIndex colNodes =
            List.indexedMap
                (\rowIndex inputNode ->
                    { id = inputNode.id
                    , label = inputNode.label
                    , x = columnX colIndex
                    , y = breathingRoom + (toFloat rowIndex * (nodeHeight + model.nodePadding))
                    , height = nodeHeight
                    }
                )
                colNodes

        columns =
            inputNodesByColumn
                |> List.indexedMap positionColumn
                |> List.indexedMap Tuple.pair
                |> Dict.fromList

        allNodes =
            Dict.values columns |> List.concat

        nodeDict =
            List.map (\n -> ( n.id, n )) allNodes

        findNode nodeId =
            List.head (List.filter (\( id, _ ) -> id == nodeId) nodeDict)
                |> Maybe.map Tuple.second

        nodeToColumn =
            inputNodes
                |> List.map (\n -> ( n.id, n.column ))
                |> Dict.fromList

        edgeThickness =
            4

        positionEdge : InputEdge -> Maybe Edge
        positionEdge inputEdge =
            Maybe.map2
                (\fromNode toNode ->
                    let
                        fromColIndex =
                            Dict.get inputEdge.fromId nodeToColumn |> Maybe.withDefault 0

                        fromWidth =
                            columnWidth fromColIndex
                    in
                    { fromId = inputEdge.fromId
                    , toId = inputEdge.toId
                    , fromX = fromNode.x + fromWidth
                    , fromY = fromNode.y + (fromNode.height / 2)
                    , toX = toNode.x
                    , toY = toNode.y + (toNode.height / 2)
                    , thickness = edgeThickness
                    }
                )
                (findNode inputEdge.fromId)
                (findNode inputEdge.toId)

        positionedEdges =
            List.filterMap positionEdge inputEdges
    in
    { columns = columns
    , edges = positionedEdges
    }


type alias RenderEvents msg =
    { onSelectNode : String -> msg
    , onDeselectNode : msg
    , onLockNode : String -> msg
    }


render : Model -> RenderEvents msg -> Diagram -> Svg msg
render model events diagram =
    let
        renderColumn colIndex nodes =
            let
                colWidth =
                    Dict.get colIndex model.columnWidths |> Maybe.withDefault 100
            in
            List.map (renderNode model events colWidth) nodes

        renderedNodes =
            diagram.columns
                |> Dict.toList
                |> List.concatMap (\( colIndex, nodes ) -> renderColumn colIndex nodes)
    in
    svg
        [ width (String.fromFloat model.svgWidth)
        , height (String.fromFloat model.svgHeight)
        , viewBox
            ("0 0 "
                ++ String.fromFloat model.svgWidth
                ++ " "
                ++ String.fromFloat model.svgHeight
            )
        ]
        [ g [] (List.map (renderEdge model) diagram.edges)
        , g [] renderedNodes
        ]


renderNode : Model -> RenderEvents msg -> Float -> Node -> Svg msg
renderNode model events nodeWidth node =
    let
        thisNodeLocked =
            List.member node.id model.lockedNodeIds

        anyNodesLocked =
            not (List.isEmpty model.lockedNodeIds)

        interactionEvents =
            if thisNodeLocked then
                [ onClick (events.onLockNode node.id)
                , cursor "pointer"
                ]

            else if anyNodesLocked then
                []

            else
                [ onClick (events.onLockNode node.id)
                , onMouseOver (events.onSelectNode node.id)
                , onMouseOut events.onDeselectNode
                , cursor "pointer"
                ]

        nodeAttrs =
            interactionEvents

        isHighlighted =
            List.member node.id model.highlightedNodeIds

        borderColor =
            if isHighlighted then
                "hotpink"

            else
                "#60A5FA"
    in
    g nodeAttrs
        [ rect
            [ x (String.fromFloat node.x)
            , y (String.fromFloat node.y)
            , width (String.fromFloat nodeWidth)
            , height (String.fromFloat node.height)
            , fill "white"
            , fillOpacity "0.5"
            , stroke borderColor
            , strokeWidth "1"
            , rx "3"
            ]
            []
        , text_
            [ x (String.fromFloat (node.x + 5))
            , y (String.fromFloat (node.y + node.height / 2 + 4))
            , fontSize (String.fromFloat model.fontSize)
            , fontFamily "system-ui, sans-serif"
            , textAnchor "start"
            , fill "#374151"
            ]
            [ text node.label ]
        ]


renderEdge : Model -> Edge -> Svg msg
renderEdge model edge =
    let
        midX =
            (edge.fromX + edge.toX) / 2

        controlX1 =
            edge.fromX + (midX - edge.fromX) * 0.5

        controlX2 =
            edge.toX - (edge.toX - midX) * 0.5

        pathD =
            String.join " "
                [ "M"
                , String.fromFloat edge.fromX
                , String.fromFloat edge.fromY
                , "C"
                , String.fromFloat controlX1
                , String.fromFloat edge.fromY
                , String.fromFloat controlX2
                , String.fromFloat edge.toY
                , String.fromFloat edge.toX
                , String.fromFloat edge.toY
                ]

        isHighlighted =
            List.member edge.fromId model.highlightedNodeIds
                || List.member edge.toId model.highlightedNodeIds

        strokeColor =
            if isHighlighted then
                "hotpink"

            else
                model.edgeColor

        opacity =
            if isHighlighted then
                1.0

            else
                model.edgeOpacity
    in
    path
        [ d pathD
        , stroke strokeColor
        , strokeWidth (String.fromFloat edge.thickness)
        , strokeOpacity (String.fromFloat opacity)
        , fill "none"
        ]
        []

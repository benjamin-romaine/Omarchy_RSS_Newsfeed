import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "NewsFeedModel.js" as NewsFeedModel

Item {
  id: root

  // Injected by omarchy-shell when this plugin is summoned/toggled.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  readonly property string pluginId: (root.manifest && root.manifest.id) || "io.github.benjamin-romaine.omarchy-newsfeed"
  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/" + root.pluginId
  readonly property int refreshIntervalMs: 20 * 60 * 1000

  property bool opened: false
  property string view: "list" // "list" | "detail"
  property var headlines: []
  property var byCategory: ({})
  property string filter: "all"
  readonly property var filterDefs: [
    { key: "all", label: "All" },
    { key: "sports", label: "Sports" },
    { key: "world", label: "World" },
    { key: "us", label: "U.S." },
    { key: "cyber", label: "Cyber" },
    { key: "tech", label: "Tech" }
  ]
  readonly property var displayedHeadlines: root.filter === "all" ? root.headlines : (root.byCategory[root.filter] || [])
  property int selectedIndex: -1
  readonly property var selectedHeadline: (selectedIndex >= 0 && selectedIndex < displayedHeadlines.length) ? displayedHeadlines[selectedIndex] : null

  property string fontFamily: Style.font.menuFamily
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(30), Style.font.heading + Style.spacing.controlPaddingY * 2)
  property int filterBarHeight: Style.space(30)
  property int rowHeight: Style.space(60)
  property int detailAreaHeight: Style.space(360)
  property int cardWidth: Math.min(Style.space(420), panel.width - Style.gapsOut * 4)
  readonly property int listContentHeight: Math.max(1, displayedHeadlines.length) * rowHeight + Math.max(0, displayedHeadlines.length - 1) * Style.spacing.xs
  readonly property int listAreaHeight: Math.min(listContentHeight, Style.space(460))
  property int cardHeight: Math.min(
    contentMargin * 2 + headerHeight + Style.spacing.md
      + (view === "list" ? (filterBarHeight + Style.spacing.md + listAreaHeight) : detailAreaHeight),
    panel.height - Style.gapsOut * 6
  )

  function open(payloadJson) {
    root.opened = true
    root.view = "list"
    root.selectedIndex = -1
    headlinesFile.reload()
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.benjamin-romaine.omarchy-newsfeed")
  }

  function setFilter(key) {
    root.filter = key
    root.view = "list"
    root.selectedIndex = -1
  }

  function selectHeadline(index) {
    if (index < 0 || index >= root.displayedHeadlines.length) return
    root.selectedIndex = index
    root.view = "detail"
  }

  function goBack() {
    root.view = "list"
    root.selectedIndex = -1
  }

  function openArticle(url) {
    if (url) Quickshell.execDetached(["xdg-open", url])
  }

  function requestRefresh() {
    refreshProc.running = true
  }

  Process {
    id: refreshProc
    command: ["python3", root.pluginDir + "/fetch-news.py"]
    onExited: headlinesFile.reload()
  }

  // Self-contained background refresh: no external systemd unit needed.
  // keepLoaded (see manifest.json) keeps this Item -- and this Timer --
  // alive for the life of the shell, even while the panel is closed.
  Timer {
    interval: root.refreshIntervalMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.requestRefresh()
  }

  FileView {
    id: headlinesFile
    path: Quickshell.env("HOME") + "/.cache/omarchy-newsfeed/headlines.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.headlines = NewsFeedModel.parsePayload(text())
      root.byCategory = NewsFeedModel.parseByCategory(text())
    }
    onLoadFailed: {
      root.headlines = []
      root.byCategory = ({})
    }
    onFileChanged: reload()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-newsfeed"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Style.bar.sizeHorizontal + Style.gapsOut * 2
      anchors.rightMargin: Style.gapsOut * 3
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.view === "detail") root.goBack()
            else root.dismiss()
            event.accepted = true
          }
        }

        Column {
          anchors.fill: parent
          anchors.topMargin: card.contentTopInset
          anchors.rightMargin: card.contentRightInset
          anchors.bottomMargin: card.contentBottomInset
          anchors.leftMargin: card.contentLeftInset
          spacing: Style.spacing.md

          // Header
          Item {
            width: parent.width
            height: root.headerHeight

            Text {
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              visible: root.view === "list"
              text: "News Feed"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.weight: Font.Medium
            }

            Text {
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              visible: root.view === "detail"
              text: "‹ Back"
              color: root.foreground
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.body

              MouseArea {
                anchors.fill: parent
                anchors.margins: -Style.space(6)
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goBack()
              }
            }

            Text {
              textFormat: Text.PlainText
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: root.view === "list"
              text: "⟳ Refresh"
              color: root.foreground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall

              MouseArea {
                anchors.fill: parent
                anchors.margins: -Style.space(6)
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestRefresh()
              }
            }
          }

          // Category filter tabs
          Row {
            width: parent.width
            height: root.filterBarHeight
            visible: root.view === "list"
            spacing: Style.space(6)

            Repeater {
              model: root.filterDefs

              delegate: Rectangle {
                required property var modelData
                readonly property bool active: root.filter === modelData.key

                width: pillLabel.implicitWidth + Style.space(18)
                height: root.filterBarHeight
                radius: height / 2
                color: active ? root.selectedBackground : "transparent"
                border.width: active ? 0 : Math.max(1, Style.space(1))
                border.color: Util.alpha(root.foreground, 0.25)

                Text {
                  id: pillLabel
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: active ? root.selectedText : root.foreground
                  opacity: active ? 1 : 0.75
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.weight: active ? Font.Medium : Font.Normal
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setFilter(modelData.key)
                }
              }
            }
          }

          // List view
          Item {
            width: parent.width
            height: root.listAreaHeight
            visible: root.view === "list"
            clip: true

            Column {
              anchors.centerIn: parent
              spacing: Style.space(6)
              visible: root.displayedHeadlines.length === 0

              Text {
                textFormat: Text.PlainText
                text: root.filter === "all" ? "No headlines cached yet" : "No cached headlines in this category yet"
                color: root.foreground
                opacity: 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignHCenter
              }
            }

            ListView {
              anchors.fill: parent
              model: root.displayedHeadlines
              spacing: Style.spacing.xs
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              delegate: Item {
                required property int index
                required property var modelData

                width: ListView.view.width
                height: root.rowHeight

                Rectangle {
                  id: dot
                  width: Style.space(6)
                  height: parent.height - Style.space(14)
                  radius: Style.space(2)
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  color: NewsFeedModel.categoryColor(modelData.category)
                }

                Column {
                  anchors.left: dot.right
                  anchors.leftMargin: Style.space(10)
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: modelData.title
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: modelData.categoryLabel + " · " + modelData.source + " · " + NewsFeedModel.relativeTime(modelData.published)
                    color: root.foreground
                    opacity: 0.55
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectHeadline(index)
                }
              }
            }
          }

          // Detail view
          Item {
            width: parent.width
            height: root.detailAreaHeight
            visible: root.view === "detail" && root.selectedHeadline !== null
            clip: true

            Column {
              anchors.fill: parent
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.selectedHeadline ? root.selectedHeadline.title : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.selectedHeadline
                  ? root.selectedHeadline.categoryLabel + " · " + root.selectedHeadline.source + " · " + NewsFeedModel.relativeTime(root.selectedHeadline.published)
                  : ""
                color: root.foreground
                opacity: 0.55
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Flickable {
                width: parent.width
                height: Math.max(Style.space(60), parent.height - Style.space(110))
                clip: true
                contentWidth: width
                contentHeight: summaryText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Text {
                  id: summaryText
                  textFormat: Text.PlainText
                  width: parent.width
                  text: root.selectedHeadline ? (root.selectedHeadline.summary || "No summary available.") : ""
                  color: root.foreground
                  opacity: 0.85
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                }
              }

              Text {
                textFormat: Text.PlainText
                text: "Open article ↗"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -Style.space(6)
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openArticle(root.selectedHeadline ? root.selectedHeadline.link : "")
                }
              }
            }
          }
        }
      }
    }
  }
}

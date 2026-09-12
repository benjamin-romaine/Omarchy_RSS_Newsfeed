import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.benjamin-romaine.omarchy-newsfeed"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "📰"
    tooltipText: "News Feed"
    onPressed: function() {
      if (root.bar) root.bar.run("omarchy-shell shell toggle io.github.benjamin-romaine.omarchy-newsfeed '{}'")
    }
  }
}

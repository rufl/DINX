import QtQuick 2.7
import QtQuick.Controls 2.2

Item {
    width: 740
    height: 420

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: guidance.implicitHeight + 16
        clip: true

        ScrollBar.vertical: ScrollBar {
            width: 10
            policy: ScrollBar.AsNeeded
        }

        Text {
            id: guidance
            x: 1
            y: 0
            width: flick.width - 16
            textFormat: Text.RichText
            wrapMode: Text.WordWrap
            antialiasing: true
            font.family: "Noto Sans"
            font.pointSize: 12
            color: "#d7dde8"
            text: "<h2>Install choices / Opções de instalação</h2>" +
                  "<p><b>Erase disk</b>: creates the layout automatically and erases all data on the selected disk. Choose it only if that is intended; verify the disk model and size.</p>" +
                  "<p><b>Install alongside</b>: keeps another system when Calamares offers this option. <b>Replace a partition</b> erases the selected partition. <b>Manual partitioning</b> is for advanced users.</p>" +
                  "<p><b>Swap is optional.</b> The default <i>None</i> installs and boots without a swap partition.</p>" +
                  "<hr/>" +
                  "<p><b>Apagar disco</b>: cria o layout automaticamente e apaga todos os dados do disco selecionado. Escolha somente se essa for sua intenção; confira o modelo e o tamanho do disco.</p>" +
                  "<p><b>Instalar ao lado</b>: mantém outro sistema quando o Calamares oferece essa opção. <b>Substituir uma partição</b> apaga a partição selecionada. <b>Particionamento manual</b> é para usuários avançados.</p>" +
                  "<p><b>Swap é opcional.</b> O padrão <i>None</i> instala e inicia sem uma partição de swap.</p>"
        }
    }
}

import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Slide {
        centeredText: qsTr("DINX is being installed.")
    }

    function onActivate() {
        presentation.currentSlide = 0
    }
}

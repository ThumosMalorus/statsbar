import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_customLabel: labelField.text
    property alias cfg_customCommand: commandField.text

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "CPU dropdown: custom tuning button"
        }
        QQC2.TextField {
            id: labelField
            Kirigami.FormData.label: "Button label:"
            placeholderText: "e.g. CoreCtrl"
        }
        QQC2.TextField {
            id: commandField
            Kirigami.FormData.label: "Command:"
            placeholderText: "e.g. corectrl"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        }
        QQC2.Label {
            text: "Shown under "Tuning tools" in the CPU dropdown. LACT, the cyan-skillfish governor controls and skillfish-tuner appear there automatically when installed."
            wrapMode: Text.WordWrap
            opacity: 0.7
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}

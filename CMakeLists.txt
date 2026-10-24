cmake_minimum_required(VERSION 3.16)

project(org.kde.nervecenter VERSION 1.0.0 LANGUAGES CXX)

set(QT_MIN_VERSION "6.6.0")
set(KF6_MIN_VERSION "6.0.0")

# Find Extra CMake Modules (ECM) from KDE Frameworks 6
find_package(ECM ${KF6_MIN_VERSION} QUIET NO_MODULE)

if(ECM_FOUND)
    set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

    include(KDEInstallDirs)
    include(KDECMakeSettings)
    include(KDECompilerSettings NO_POLICY_SCOPE)
    include(FeatureSummary)

    find_package(Plasma ${KF6_MIN_VERSION} QUIET)

    if(Plasma_FOUND)
        plasma_install_package(nervecenter org.kde.nervecenter wallpapers wallpaper)
    else()
        install(DIRECTORY nervecenter/
                DESTINATION ${KDE_INSTALL_DATADIR}/plasma/wallpapers/org.kde.nervecenter
                PATTERN ".git*" EXCLUDE
                PATTERN "__pycache__*" EXCLUDE)
    endif()
else()
    include(GNUInstallDirs)
    install(DIRECTORY nervecenter/
            DESTINATION ${CMAKE_INSTALL_DATADIR}/plasma/wallpapers/org.kde.nervecenter
            PATTERN ".git*" EXCLUDE
            PATTERN "__pycache__*" EXCLUDE)
endif()

# ─────────────────────────────────────────────────────────────────────────────
# Helper targets for development and user-space package management
# ─────────────────────────────────────────────────────────────────────────────
find_program(KPACKAGETOOL6_BIN kpackagetool6)

if(KPACKAGETOOL6_BIN)
    # User-space install / upgrade without root privileges
    add_custom_target(install_user
        COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/install.sh
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Installing NerveCenter into user plasma wallpapers (~/.local/share/plasma/wallpapers/org.kde.nervecenter)"
        USES_TERMINAL
    )

    # User-space upgrade / hot reload
    add_custom_target(reload
        COMMAND ${KPACKAGETOOL6_BIN} --type Plasma/Wallpaper -u ${CMAKE_CURRENT_SOURCE_DIR}/nervecenter
        COMMENT "Reloading NerveCenter package via kpackagetool6"
        USES_TERMINAL
    )

    # User-space uninstall
    add_custom_target(uninstall_user
        COMMAND ${KPACKAGETOOL6_BIN} --type Plasma/Wallpaper -r org.kde.nervecenter
        COMMENT "Removing NerveCenter from user plasma wallpapers"
        USES_TERMINAL
    )
endif()

if(ECM_FOUND)
    feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)
endif()

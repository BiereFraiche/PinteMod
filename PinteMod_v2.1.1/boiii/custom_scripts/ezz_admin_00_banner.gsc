// ============================================================
// PinteMod — Startup Banner v2.1.1
// Fichier : ezz_admin_00_banner.gsc
// Créé par BiereFraiche et ChatGPT
//
// Chargé avant le Core et les autres modules pour afficher
// l'attribution en première ligne du démarrage PinteMod.
// ============================================================

autoexec function init()
{
    level.pintemod_startup_banner_loaded = true;

    println("^5[PinteMod]^7 v2.1.1 | Created by BiereFraiche and ChatGPT");
}

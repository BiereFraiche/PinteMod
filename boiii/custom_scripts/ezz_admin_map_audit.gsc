// ============================================================
// PinteMod — Map Compatibility Audit v2.1.1
// Conservative, declared capability profiles. No unsupported feature
// is promoted to SUPPORTED without a matching declaration/validation.
// ============================================================

#namespace ezz_admin_map_audit;

#using custom_scripts\ezz_admin_registry;

function map_audit_profile_base(map_name)
{
    profile = SpawnStruct();
    profile.map_id = map_name;
    profile.name = ezz_admin_registry::get_map_display_name(map_name);
    profile.profile = "CUSTOM_UNPROFILED";
    profile.power = "NOT_DECLARED";
    profile.pap = "NOT_DECLARED";
    profile.passages = "GENERIC_SAFE_SCAN";
    profile.events = "NOT_DECLARED";
    profile.music = "NOT_DECLARED";
    profile.bosses = "NONE_DECLARED";
    profile.dog_rounds = "NOT_DECLARED";
    profile.ee_profile = "NOT_DECLARED";
    profile.ee_state = "NOT_APPLICABLE";
    profile.special_weapons = "DYNAMIC_ONLY";
    profile.spawn_late_join = "GENERIC_SUPPORTED";
    profile.limitations = "Custom map profile not registered";
    return profile;
}

function map_audit_apply_official(profile)
{
    profile.profile = "OFFICIAL";
    profile.passages = "SUPPORTED_STANDARD_ONLY";
    profile.spawn_late_join = "SUPPORTED";
    profile.ee_profile = "DECLARED";
    profile.ee_state = "DIAGNOSTIC";
    profile.limitations = "Quest-specific mechanisms are not forced";

    switch (profile.map_id)
    {
        case "zm_zod":
            profile.power = "PARTIAL_BEAST_SWITCHES";
            profile.pap = "PARTIAL_RITUAL_ACCESS";
            profile.events = "SUPPORTED_MARGWA";
            profile.music = "SUPPORTED";
            profile.bosses = "MARGWA";
            profile.dog_rounds = "NOT_DECLARED";
            profile.special_weapons = "APOTHICON_SERVANT, ARNIES, SWORD";
            break;

        case "zm_factory":
            profile.power = "SUPPORTED";
            profile.pap = "VALIDATED";
            profile.events = "LIMITED";
            profile.music = "NATIVE_STATE_ONLY";
            profile.bosses = "NONE_DECLARED";
            profile.dog_rounds = "SUPPORTED_NATIVE";
            profile.ee_state = "NOT_APPLICABLE";
            profile.special_weapons = "WUNDERWAFFE, ANNIHILATOR";
            break;

        case "zm_castle":
            profile.power = "SUPPORTED";
            profile.pap = "PARTIAL_MAP_ACCESS";
            profile.events = "SUPPORTED_PANZER";
            profile.music = "SUPPORTED";
            profile.bosses = "PANZER";
            profile.dog_rounds = "SUPPORTED_NATIVE";
            profile.special_weapons = "BOWS, RAGNAROK";
            break;

        case "zm_island":
            profile.power = "PARTIAL_DUAL_GENERATOR";
            profile.pap = "PARTIAL_MACHINE_PARTS";
            profile.events = "SUPPORTED_THRASHER";
            profile.music = "UNAVAILABLE_NATIVE_REGISTRY";
            profile.bosses = "THRASHER";
            profile.dog_rounds = "SUPPORTED_NATIVE";
            profile.special_weapons = "KT4, MASAMUNE, SKULL";
            break;

        case "zm_stalingrad":
            profile.power = "SUPPORTED";
            profile.pap = "PARTIAL_DRAGON_ACCESS";
            profile.events = "SUPPORTED_MECHZ";
            profile.music = "SUPPORTED";
            profile.bosses = "MECHZ";
            profile.dog_rounds = "NOT_DECLARED";
            profile.special_weapons = "GKZ45, GAUNTLET, DRAGON_STRIKE";
            break;

        case "zm_genesis":
            profile.power = "PARTIAL_CORRUPTION_ENGINES";
            profile.pap = "PARTIAL_APOTHICON_ACCESS";
            profile.events = "SUPPORTED_MARGWA_PANZER";
            profile.music = "SUPPORTED";
            profile.bosses = "MARGWA, PANZER";
            profile.dog_rounds = "NOT_DECLARED";
            profile.special_weapons = "APOTHICON, THUNDERGUN, RAGNAROK";
            break;

        case "zm_prototype":
            profile.power = "NOT_APPLICABLE";
            profile.pap = "NOT_APPLICABLE";
            profile.events = "LIMITED";
            profile.music = "NOT_CONFIGURED";
            profile.dog_rounds = "NOT_APPLICABLE";
            profile.ee_state = "NOT_APPLICABLE";
            profile.special_weapons = "BOX_PROFILE";
            break;

        case "zm_asylum":
            profile.power = "SUPPORTED";
            profile.pap = "NOT_APPLICABLE";
            profile.events = "LIMITED";
            profile.music = "SUPPORTED";
            profile.dog_rounds = "SUPPORTED_NATIVE";
            profile.ee_state = "NOT_APPLICABLE";
            profile.special_weapons = "BOX_PROFILE";
            break;

        case "zm_sumpf":
            profile.power = "SUPPORTED";
            profile.pap = "NOT_APPLICABLE";
            profile.events = "LIMITED";
            profile.music = "SUPPORTED";
            profile.dog_rounds = "SUPPORTED_NATIVE";
            profile.ee_state = "NOT_APPLICABLE";
            profile.special_weapons = "WUNDERWAFFE";
            break;

        case "zm_theater":
            profile.power = "SUPPORTED";
            profile.pap = "PARTIAL_TELEPORTER_ACCESS";
            profile.events = "LIMITED";
            profile.music = "SUPPORTED";
            profile.dog_rounds = "SUPPORTED_NATIVE";
            profile.ee_state = "NOT_APPLICABLE";
            profile.special_weapons = "THUNDERGUN";
            break;

        case "zm_cosmodrome":
            profile.power = "SUPPORTED";
            profile.pap = "PARTIAL_ROCKET_ACCESS";
            profile.events = "LIMITED";
            profile.music = "SUPPORTED";
            profile.dog_rounds = "NOT_DECLARED";
            profile.special_weapons = "THUNDERGUN, GERSH, MATRYOSHKA";
            break;

        case "zm_temple":
            profile.power = "SUPPORTED";
            profile.pap = "PARTIAL_PRESSURE_PLATES";
            profile.events = "LIMITED";
            profile.music = "SUPPORTED";
            profile.dog_rounds = "NOT_DECLARED";
            profile.special_weapons = "BABY_GUN, MONKEY_BOMB";
            break;

        case "zm_moon":
            profile.power = "SUPPORTED";
            profile.pap = "SUPPORTED_AREA51_MACHINE";
            profile.events = "SUPPORTED_ASTRONAUT";
            profile.music = "SUPPORTED";
            profile.bosses = "ASTRONAUT";
            profile.dog_rounds = "NOT_APPLICABLE";
            profile.special_weapons = "WAVE_GUN, QED, GERSH";
            break;

        case "zm_tomb":
            profile.power = "PARTIAL_SIX_GENERATORS";
            profile.pap = "PARTIAL_SIX_GENERATORS";
            profile.events = "SUPPORTED_PANZER";
            profile.music = "SUPPORTED";
            profile.bosses = "PANZER";
            profile.dog_rounds = "NOT_DECLARED";
            profile.ee_state = "OFFICIAL";
            profile.special_weapons = "STAFFS, G_STRIKE, RAY_GUN_MK2";
            profile.limitations = "Staff upgrades remain quest-gated; EE official detector validated for Origins only";
            break;
    }

    return profile;
}

function map_audit_get_registered_custom(map_name)
{
    if (!isdefined(level.pintemod_custom_map_profiles))
        return undefined;

    for (i = 0; i < level.pintemod_custom_map_profiles.size; i++)
    {
        profile = level.pintemod_custom_map_profiles[i];

        if (isdefined(profile) && isdefined(profile.map_id) &&
            toLower(profile.map_id) == map_name)
        {
            return profile;
        }
    }

    return undefined;
}

function register_custom_map_profile(profile)
{
    if (!isdefined(profile) || !isdefined(profile.map_id) || profile.map_id == "")
    {
        println("^1[PinteMod Map Audit]^7 Custom profile rejected: map_id missing");
        return false;
    }

    if (!isdefined(level.pintemod_custom_map_profiles))
        level.pintemod_custom_map_profiles = [];

    profile.map_id = toLower(profile.map_id);
    level.pintemod_custom_map_profiles[level.pintemod_custom_map_profiles.size] = profile;
    println("^2[PinteMod Map Audit]^7 Custom profile registered: " + profile.map_id);
    return true;
}

function map_audit_get_profile(map_name)
{
    map_name = toLower(map_name);
    custom = map_audit_get_registered_custom(map_name);

    if (isdefined(custom))
        return custom;

    profile = map_audit_profile_base(map_name);

    if (ezz_admin_registry::is_official_map(map_name))
        profile = map_audit_apply_official(profile);

    return profile;
}

function map_audit_warning_count(profile)
{
    warnings = 0;
    fields = [];
    fields[0] = profile.power;
    fields[1] = profile.pap;
    fields[2] = profile.events;
    fields[3] = profile.music;
    fields[4] = profile.dog_rounds;
    fields[5] = profile.ee_state;

    for (i = 0; i < fields.size; i++)
    {
        value = toLower(fields[i]);

        if (value.size >= 7 && GetSubStr(value, 0, 7) == "partial") warnings++;
        else if (value.size >= 4 && GetSubStr(value, 0, 4) == "not_") warnings++;
        else if (value == "limited" || value == "diagnostic" || value == "unavailable_native_registry") warnings++;
    }

    return warnings;
}

function map_audit_print(full_mode)
{
    map_name = toLower(GetDvarString("mapname"));
    profile = map_audit_get_profile(map_name);

    println("^5========== [PinteMod Map Audit] ==========");
    println("^7Map             " + profile.name + " (" + profile.map_id + ")");
    println("^7Profile         " + profile.profile);
    println("^7Power           " + profile.power);
    println("^7Pack-a-Punch    " + profile.pap);
    println("^7Passages        " + profile.passages);
    println("^7Events          " + profile.events);
    println("^7Music           " + profile.music);
    println("^7Bosses          " + profile.bosses);
    println("^7Dog rounds      " + profile.dog_rounds);
    println("^7EE profile      " + profile.ee_profile + " / " + profile.ee_state);
    println("^7Special weapons " + profile.special_weapons);
    println("^7Spawn/Late Join " + profile.spawn_late_join);
    println("^7Warnings        " + map_audit_warning_count(profile));

    if (isdefined(full_mode) && full_mode)
    {
        println("^5----- Known limitations -----");
        println("^7" + profile.limitations);
        println("^7States are declarations, not automatic server validation.");
        println("^7Custom maps may register a profile through register_custom_map_profile().");
    }

    println("^5============================================");
}

function map_audit_test_assert(result, condition, name)
{
    result.total++;
    if (condition) { result.passed++; println("^2[PASS]^7 " + name); }
    else { result.failed++; println("^1[FAIL]^7 " + name); }
}

function map_audit_run_grouped_suite()
{
    result = SpawnStruct(); result.total = 0; result.passed = 0; result.failed = 0;
    origins = map_audit_get_profile("zm_tomb");
    giant = map_audit_get_profile("zm_factory");
    custom = map_audit_get_profile("zm_custom_example");

    map_audit_test_assert(result, ezz_admin_registry::official_map_codes().size == 14, "Fourteen official maps");
    map_audit_test_assert(result, origins.ee_state == "OFFICIAL", "Origins EE state is OFFICIAL");
    map_audit_test_assert(result, giant.pap == "VALIDATED", "The Giant PaP remains validated");
    map_audit_test_assert(result, custom.profile == "CUSTOM_UNPROFILED", "Unknown custom map stays unprofiled");
    map_audit_test_assert(result, custom.power != "SUPPORTED", "Custom map never receives implicit support");
    return result;
}

function cmd_ezzmapaudit(args)
{
    full_mode = args.size > 0 && toLower(args[0]) == "full";
    map_audit_print(full_mode);
}

autoexec function init()
{
    if (isdefined(level.pintemod_map_audit_loaded) && level.pintemod_map_audit_loaded)
        return;

    level.pintemod_map_audit_loaded = true;
    level.pintemod_map_audit_version = "2.1.1";
    level.pintemod_custom_map_profiles = [];
    addcommand("ezzmapaudit", ::cmd_ezzmapaudit);
    println("^5[PinteMod]^7 Map Audit v2.1.1 loaded");
}

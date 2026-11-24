// Generated from materials.json. Raw atlas roles are separate from shading material IDs.
int arenaMaterialRole(int rawId) { if (rawId >= 10240 && rawId < 10258) return rawId - 10240; return rawId >= 10200 && rawId < 10234 ? (rawId - 10200) / 2 : -1; }
int arenaBaseMaterial(int rawId) {
    if (rawId >= 10240 && rawId < 10258) return rawId == 10248 ? 10007 : 10003;   // end blocks; 10248 = purpur pillar
    const int ids[36] = int[36](10010, 10012, 10010, 10015, 10008, 10013, 10009, 0, 10006, 10014, 10002, 10002, 10002, 10002, 10002, 10002, 10007, 0, 10003, 10003, 10003, 0, 10003, 10003, 10009, 0, 0, 0, 10002, 10002, 0, 0, 0, 0, 0, 0);
    return rawId >= 10200 && rawId < 10234 ? ids[rawId - 10200] : rawId;
}

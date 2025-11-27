
pkt = zigbee_decode_from_file("zigbee_phy_baseband.txt");
info = mac_parse(pkt.psdu_no_fcs);
mac_print(info);
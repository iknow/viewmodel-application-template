{
  actioncable = {
    dependencies = ["actionpack" "activesupport" "nio4r" "websocket-driver"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "117vxic67jnw6q637kmsb3ryj0x485295pz9a9y4z8xn9bdlsl0z";
      type = "gem";
    };
    version = "7.0.8";
  };
  actionmailbox = {
    dependencies = ["actionpack" "activejob" "activerecord" "activestorage" "activesupport" "mail" "net-imap" "net-pop" "net-smtp"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1r8ldj2giaz8cn49qkdqn5zc29gbsr5ky4fg6r7ali0yh1xh684l";
      type = "gem";
    };
    version = "7.0.8";
  };
  actionmailer = {
    dependencies = ["actionpack" "actionview" "activejob" "activesupport" "mail" "net-imap" "net-pop" "net-smtp" "rails-dom-testing"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0w6gvj7ybniq89834hqww9rj2xypz9l91f8niwaws2yq1qklymr2";
      type = "gem";
    };
    version = "7.0.8";
  };
  actionpack = {
    dependencies = ["actionview" "activesupport" "rack" "rack-test" "rails-dom-testing" "rails-html-sanitizer"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1l319p0gipfgq8bp8dvbv97qqb72rad9zcqn5snhgv20cmpqr69b";
      type = "gem";
    };
    version = "7.0.8";
  };
  actiontext = {
    dependencies = ["actionpack" "activerecord" "activestorage" "activesupport" "globalid" "nokogiri"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0i47r3n2m8qm002gx7c0lx1pv15pr2zy57dm8j38x960rsb655pp";
      type = "gem";
    };
    version = "7.0.8";
  };
  actionview = {
    dependencies = ["activesupport" "builder" "erubi" "rails-dom-testing" "rails-html-sanitizer"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0xnpdwj1d8m6c2d90jp9cs50ggiz0jj02ls2h9lg68k4k8mnjbd2";
      type = "gem";
    };
    version = "7.0.8";
  };
  activejob = {
    dependencies = ["activesupport" "globalid"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1cn1ic7ml75jm0c10s7cm5mvcgfnafj0kjvvjavpjcxgz6lxcqyb";
      type = "gem";
    };
    version = "7.0.8";
  };
  activemodel = {
    dependencies = ["activesupport"];
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "004w8zaz2g3y6lnrsvlcmljll0m3ndqpgwf0wfscgq6iysibiglm";
      type = "gem";
    };
    version = "7.0.8";
  };
  activerecord = {
    dependencies = ["activemodel" "activesupport"];
    groups = ["default" "development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "04wavps80q3pvhvfbmi4gs102y1p6mxbg8xylzvib35b6m92adpj";
      type = "gem";
    };
    version = "7.0.8";
  };
  activerecord-import = {
    dependencies = ["activerecord"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0n1zmpdwxic878zbc0hphbdk18619ifh6ikbxc24mv1sx7l2srq4";
      type = "gem";
    };
    version = "1.5.1";
  };
  activestorage = {
    dependencies = ["actionpack" "activejob" "activerecord" "activesupport" "marcel" "mini_mime"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0d6vm6alsp0g6f3548b615zxbz8l2wrmaikwgsf8kv11wf6swb4c";
      type = "gem";
    };
    version = "7.0.8";
  };
  activesupport = {
    dependencies = ["concurrent-ruby" "i18n" "minitest" "tzinfo"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "188kbwkn1lbhz40ala8ykp20jzqphgc68g3d8flin8cqa2xid0s5";
      type = "gem";
    };
    version = "7.0.8";
  };
  acts_as_manual_list = {
    dependencies = ["activerecord" "activesupport" "lazily"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1c5fkq0pjv10smzn3gfgsgslwfwij7bn8h5b589n09zxbvqc8ppi";
      type = "gem";
    };
    version = "0.1.2";
  };
  addressable = {
    dependencies = ["public_suffix"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "05r1fwy487klqkya7vzia8hnklcxy4vr92m9dmni3prfwk6zpw33";
      type = "gem";
    };
    version = "2.8.5";
  };
  annotate = {
    dependencies = ["activerecord" "rake"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1lw0fxb5mirsdp3bp20gjyvs7clvi19jbxnrm2ihm20kzfhvlqcs";
      type = "gem";
    };
    version = "3.2.0";
  };
  ast = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "04nc8x27hlzlrr5c2gn7mar4vdr0apw5xg22wp6m8dx3wqr04a0y";
      type = "gem";
    };
    version = "2.4.2";
  };
  aws-eventstream = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0gvdg4yx4p9av2glmp7vsxhs0n8fj1ga9kq2xdb8f95j7b04qhzi";
      type = "gem";
    };
    version = "1.3.0";
  };
  aws-partitions = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1qfaj4k0c79pznws6a55fk4q01syv1ssdbqgz4imirz71kivzsqd";
      type = "gem";
    };
    version = "1.862.0";
  };
  aws-sdk-core = {
    dependencies = ["aws-eventstream" "aws-partitions" "aws-sigv4" "jmespath"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "19nglxz49nlzgsvnivb3bdm17vxjn1ng2br8659xv48nzjrmyid3";
      type = "gem";
    };
    version = "3.190.0";
  };
  aws-sdk-kms = {
    dependencies = ["aws-sdk-core" "aws-sigv4"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1isrj19kzy9sb7a76a1c2n5x0d9lg1h2n7fp7cn13xjis0hpnlxj";
      type = "gem";
    };
    version = "1.74.0";
  };
  aws-sdk-s3 = {
    dependencies = ["aws-sdk-core" "aws-sdk-kms" "aws-sigv4"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0bnhpmi0iiaj88rqc5lhhnp2gyrk4fs8xz51lj36wwzng94qinya";
      type = "gem";
    };
    version = "1.141.0";
  };
  aws-sigv4 = {
    dependencies = ["aws-eventstream"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1g3w27wzjy4si6kp49w10as6ml6g6zl3xrfqs5ikpfciidv9kpc4";
      type = "gem";
    };
    version = "1.8.0";
  };
  backport = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0xbzzjrgah0f8ifgd449kak2vyf30micpz6x2g82aipfv7ypsb4i";
      type = "gem";
    };
    version = "1.2.0";
  };
  base_x = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "065wfmfqcm037cyv3bk7hi3shmzilp6kl00cqzqq4bp1pkblxb33";
      type = "gem";
    };
    version = "0.8.1";
  };
  bcrypt = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "16a0g2q40biv93i1hch3gw8rbmhp77qnnifj1k0a6m7dng3zh444";
      type = "gem";
    };
    version = "3.1.20";
  };
  benchmark = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0wghmhwjzv4r9mdcny4xfz2h2cm7ci24md79rvy2x65r4i99k9sc";
      type = "gem";
    };
    version = "0.3.0";
  };
  bindex = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0zmirr3m02p52bzq4xgksq4pn8j641rx5d4czk68pv9rqnfwq7kv";
      type = "gem";
    };
    version = "0.8.1";
  };
  bootsnap = {
    dependencies = ["msgpack"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0iqkzby0fdgi786m873nm0ckmc847wy9a4ydinb29m7hd3fs83kb";
      type = "gem";
    };
    version = "1.17.0";
  };
  builder = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "045wzckxpwcqzrjr353cxnyaxgf0qg22jh00dcx7z38cys5g1jlr";
      type = "gem";
    };
    version = "3.2.4";
  };
  chewy = {
    dependencies = ["activesupport" "elasticsearch" "elasticsearch-dsl"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0zca6v8i66jkxfdfjnn9xwg21pk95qn4ic8vzfvrx49d6sb8319y";
      type = "gem";
    };
    version = "7.3.4";
  };
  concurrent-ruby = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0krcwb6mn0iklajwngwsg850nk8k9b35dhmc2qkbdqvmifdi2y9q";
      type = "gem";
    };
    version = "1.2.2";
  };
  crack = {
    dependencies = ["rexml"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1cr1kfpw3vkhysvkk3wg7c54m75kd68mbm9rs5azdjdq57xid13r";
      type = "gem";
    };
    version = "0.4.5";
  };
  crass = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0pfl5c0pyqaparxaqxi6s4gfl21bdldwiawrc0aknyvflli60lfw";
      type = "gem";
    };
    version = "1.0.6";
  };
  dalli = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "137xw0nl7ixxqyam6fjgmzl24i3rdml37whgnks8y35w92i95447";
      type = "gem";
    };
    version = "3.2.6";
  };
  date = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "149jknsq999gnhy865n33fkk22s0r447k76x9pmcnnwldfv2q7wp";
      type = "gem";
    };
    version = "3.3.4";
  };
  debug = {
    dependencies = ["irb" "reline"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1nhkl066109cbldd3dc218wldish6v8iq63zalgvb95986nx2ash";
      type = "gem";
    };
    version = "1.8.0";
  };
  deep_preloader = {
    dependencies = ["activerecord"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "135adkj6z8msmb7x55ymqbaimxpbqrycbmwx7il0dcl07b431zyy";
      type = "gem";
    };
    version = "1.1.0";
  };
  diff-lcs = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0rwvjahnp7cpmracd8x732rjgnilqv2sx7d1gfrysslc3h039fa9";
      type = "gem";
    };
    version = "1.5.0";
  };
  e2mmap = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0n8gxjb63dck3vrmsdcqqll7xs7f3wk78mw8w0gdk9wp5nx6pvj5";
      type = "gem";
    };
    version = "0.1.0";
  };
  elasticsearch = {
    dependencies = ["elasticsearch-api" "elasticsearch-transport"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0havyxmvl157a653prspnbhgdchlx44xqxl170v1im5ggxwavcaq";
      type = "gem";
    };
    version = "7.13.3";
  };
  elasticsearch-api = {
    dependencies = ["multi_json"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0bmssarkk7lqkjdn8c9j7jvxcnn4hg1zcmhsky8bfvc99k33b3w8";
      type = "gem";
    };
    version = "7.13.3";
  };
  elasticsearch-dsl = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "174m3fwm3mawbkjg2xbmqvljq7ava4s95m8vpg5khcvfj506wxfk";
      type = "gem";
    };
    version = "0.1.10";
  };
  elasticsearch-transport = {
    dependencies = ["faraday" "multi_json"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0blfii8qvj0m6bg9sbfynxc40in7zfmw2wpi4clv7d9gclk053db";
      type = "gem";
    };
    version = "7.13.3";
  };
  erubi = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "08s75vs9cxlc4r1q2bjg4br8g9wc5lc5x5vl0vv4zq5ivxsdpgi7";
      type = "gem";
    };
    version = "1.12.0";
  };
  et-orbi = {
    dependencies = ["tzinfo"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1d2z4ky2v15dpcz672i2p7lb2nc793dasq3yq3660h2az53kss9v";
      type = "gem";
    };
    version = "1.2.7";
  };
  ethon = {
    dependencies = ["ffi"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "17ix0mijpsy3y0c6ywrk5ibarmvqzjsirjyprpsy3hwax8fdm85v";
      type = "gem";
    };
    version = "0.16.0";
  };
  factory_bot = {
    dependencies = ["activesupport"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0rk4mq7hkasqgn84n9kqlyl2smhzdhya7xjcg7riwwib44jgydpj";
      type = "gem";
    };
    version = "6.4.2";
  };
  factory_bot_rails = {
    dependencies = ["factory_bot" "railties"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1q72x1xih7x19lg1196dahxyas87syrw5x2h1fjszf4ydxi4yf0c";
      type = "gem";
    };
    version = "6.4.2";
  };
  faraday = {
    dependencies = ["faraday-em_http" "faraday-em_synchrony" "faraday-excon" "faraday-httpclient" "faraday-multipart" "faraday-net_http" "faraday-net_http_persistent" "faraday-patron" "faraday-rack" "faraday-retry" "ruby2_keywords"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1c760q0ks4vj4wmaa7nh1dgvgqiwaw0mjr7v8cymy7i3ffgjxx90";
      type = "gem";
    };
    version = "1.10.3";
  };
  faraday-em_http = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "12cnqpbak4vhikrh2cdn94assh3yxza8rq2p9w2j34bqg5q4qgbs";
      type = "gem";
    };
    version = "1.0.0";
  };
  faraday-em_synchrony = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1vgrbhkp83sngv6k4mii9f2s9v5lmp693hylfxp2ssfc60fas3a6";
      type = "gem";
    };
    version = "1.0.0";
  };
  faraday-excon = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0h09wkb0k0bhm6dqsd47ac601qiaah8qdzjh8gvxfd376x1chmdh";
      type = "gem";
    };
    version = "1.1.0";
  };
  faraday-httpclient = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0fyk0jd3ks7fdn8nv3spnwjpzx2lmxmg2gh4inz3by1zjzqg33sc";
      type = "gem";
    };
    version = "1.0.1";
  };
  faraday-multipart = {
    dependencies = ["multipart-post"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "09871c4hd7s5ws1wl4gs7js1k2wlby6v947m2bbzg43pnld044lh";
      type = "gem";
    };
    version = "1.0.4";
  };
  faraday-net_http = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1fi8sda5hc54v1w3mqfl5yz09nhx35kglyx72w7b8xxvdr0cwi9j";
      type = "gem";
    };
    version = "1.0.1";
  };
  faraday-net_http_persistent = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dc36ih95qw3rlccffcb0vgxjhmipsvxhn6cw71l7ffs0f7vq30b";
      type = "gem";
    };
    version = "1.2.0";
  };
  faraday-patron = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "19wgsgfq0xkski1g7m96snv39la3zxz6x7nbdgiwhg5v82rxfb6w";
      type = "gem";
    };
    version = "1.0.0";
  };
  faraday-rack = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1h184g4vqql5jv9s9im6igy00jp6mrah2h14py6mpf9bkabfqq7g";
      type = "gem";
    };
    version = "1.0.0";
  };
  faraday-retry = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "153i967yrwnswqgvnnajgwp981k9p50ys1h80yz3q94rygs59ldd";
      type = "gem";
    };
    version = "1.0.3";
  };
  faraday_middleware-aws-sigv4 = {
    dependencies = ["aws-sigv4" "faraday"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0i7ljl6dnsfmpdm8z3hi45wh3wbqhaz2hg6i6bkzaibr92nm4dla";
      type = "gem";
    };
    version = "0.6.1";
  };
  ffi = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1yvii03hcgqj30maavddqamqy50h7y6xcn2wcyq72wn823zl4ckd";
      type = "gem";
    };
    version = "1.16.3";
  };
  fugit = {
    dependencies = ["et-orbi" "raabro"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "08fjxnzqvql8mg8wbpddg6fl9lrsp38dwhiyfpfsz550524f2ap9";
      type = "gem";
    };
    version = "1.9.0";
  };
  fuubar = {
    dependencies = ["rspec-core" "ruby-progressbar"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1028vn7j3kc5qqwswrf3has3qm4j9xva70xmzb3n29i89f0afwmj";
      type = "gem";
    };
    version = "2.5.1";
  };
  globalid = {
    dependencies = ["activesupport"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1sbw6b66r7cwdx3jhs46s4lr991969hvigkjpbdl7y3i31qpdgvh";
      type = "gem";
    };
    version = "1.2.1";
  };
  good_job = {
    dependencies = ["activejob" "activerecord" "concurrent-ruby" "fugit" "railties" "thor"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1lqj6mpf14qia3np44y3bp9266ijlyly7zk8p6s0cqq3ngn5vjm1";
      type = "gem";
    };
    version = "3.21.5";
  };
  hashdiff = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1jf9dxgjz6z7fvymyz2acyvn9iyvwkn6d9sk7y4fxwbmfc75yimm";
      type = "gem";
    };
    version = "1.1.0";
  };
  honeybadger = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "01b7g0m8r000c4z4gzzkiqfbx2m9fjc2n1nzq04s0xr5irg974zh";
      type = "gem";
    };
    version = "5.3.0";
  };
  i18n = {
    dependencies = ["concurrent-ruby"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0qaamqsh5f3szhcakkak8ikxlzxqnv49n2p7504hcz2l0f4nj0wx";
      type = "gem";
    };
    version = "1.14.1";
  };
  iknow_cache = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0gjbwyb487fh3fkdggli1ypq902zj0n0nj49476ybp5kaq05j5aw";
      type = "gem";
    };
    version = "1.2.0";
  };
  iknow_params = {
    dependencies = ["activesupport" "json-schema" "tzinfo"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0sxlgpwkzppi20rgk0phry17c3wa03kj4z8wr9y9nsj9i84krybz";
      type = "gem";
    };
    version = "2.3.1";
  };
  iknow_view_models = {
    dependencies = ["actionpack" "activerecord" "activesupport" "acts_as_manual_list" "concurrent-ruby" "deep_preloader" "iknow_cache" "iknow_params" "jbuilder" "json_schema" "keyword_builder" "lazily" "oj" "renum" "rgl" "safe_values"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1y14xv0x4gyxvsb2b7b6s012nv2j56kyj5wkjx7bapdhhwf2a9xk";
      type = "gem";
    };
    version = "3.7.6";
  };
  io-console = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dikardh14c72gd9ypwh8dim41wvqmzfzf35mincaj5yals9m7ff";
      type = "gem";
    };
    version = "0.6.0";
  };
  irb = {
    dependencies = ["rdoc" "reline"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0appka5sbafafn4f8d285skxw3qkhbap28vn9ms0pf7pbp7s2449";
      type = "gem";
    };
    version = "1.9.1";
  };
  jaro_winkler = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "10fd3i92897blalxfkgc0jjv0qqx31v7cm7j2b6a3b97an0bfz80";
      type = "gem";
    };
    version = "1.5.6";
  };
  jbuilder = {
    dependencies = ["actionview" "activesupport"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1h58xgmp0fqpnd6mvw0zl0f76119v8lnf4xabqhckbzl6jrk8qpa";
      type = "gem";
    };
    version = "2.11.5";
  };
  jmespath = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1cdw9vw2qly7q7r41s7phnac264rbsdqgj4l0h4nqgbjb157g393";
      type = "gem";
    };
    version = "1.6.2";
  };
  jsbundling-rails = {
    dependencies = ["railties"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0kssshk7n9fyn2j7d7i17dl6nsy9k96jjih6x4y0r6kcad58rjwa";
      type = "gem";
    };
    version = "1.2.1";
  };
  json = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0wi7g6c8q0v1kahwp38mv8d526p1n2ddsr79ajx84idvih0c601i";
      type = "gem";
    };
    version = "2.7.0";
  };
  json-schema = {
    dependencies = ["addressable"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0gdvm83yaa5n8hwapwzxwfcmbypiq2i0zfx4mzz67wg55p2cnli4";
      type = "gem";
    };
    version = "3.0.0";
  };
  json_schema = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0nzcnb9j7bbj3nc6izwlsxky8j4xly345qzfg5v5n6550kqfmqfn";
      type = "gem";
    };
    version = "0.21.0";
  };
  keyword_builder = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0srxic18xhqscj8l6csxrzqr7aar5mb766b91ycrcww58qqvnfg7";
      type = "gem";
    };
    version = "1.0.0";
  };
  kramdown = {
    dependencies = ["rexml"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ic14hdcqxn821dvzki99zhmcy130yhv5fqfffkcf87asv5mnbmn";
      type = "gem";
    };
    version = "2.4.0";
  };
  kramdown-parser-gfm = {
    dependencies = ["kramdown"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0a8pb3v951f4x7h968rqfsa19c8arz21zw1vaj42jza22rap8fgv";
      type = "gem";
    };
    version = "1.1.0";
  };
  language_server-protocol = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0gvb1j8xsqxms9mww01rmdl78zkd72zgxaap56bhv8j45z05hp1x";
      type = "gem";
    };
    version = "3.17.0.3";
  };
  lazily = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1fnlv4zqnc0gml21j2b9g1fqlzwn63nrdr5c0546y3apj9ysmb60";
      type = "gem";
    };
    version = "0.2.1";
  };
  loadable_config = {
    dependencies = ["json_schema"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1h3zfjp6j49728l9xzv7g5gigqfdjvp9bldalfb314c76y70m8al";
      type = "gem";
    };
    version = "1.0.4";
  };
  lograge = {
    dependencies = ["actionpack" "activesupport" "railties" "request_store"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1qcsvh9k4c0cp6agqm9a8m4x2gg7vifryqr7yxkg2x9ph9silds2";
      type = "gem";
    };
    version = "0.14.0";
  };
  loofah = {
    dependencies = ["crass" "nokogiri"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1zkjqf37v2d7s11176cb35cl83wls5gm3adnfkn2zcc61h3nxmqh";
      type = "gem";
    };
    version = "2.22.0";
  };
  mail = {
    dependencies = ["mini_mime" "net-imap" "net-pop" "net-smtp"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1bf9pysw1jfgynv692hhaycfxa8ckay1gjw5hz3madrbrynryfzc";
      type = "gem";
    };
    version = "2.8.1";
  };
  marcel = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0kky3yiwagsk8gfbzn3mvl2fxlh3b39v6nawzm4wpjs6xxvvc4x0";
      type = "gem";
    };
    version = "1.0.2";
  };
  method_source = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1pnyh44qycnf9mzi1j6fywd5fkskv3x7nmsqrrws0rjn5dd4ayfp";
      type = "gem";
    };
    version = "1.0.0";
  };
  mini_mime = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1vycif7pjzkr29mfk4dlqv3disc5dn0va04lkwajlpr1wkibg0c6";
      type = "gem";
    };
    version = "1.1.5";
  };
  mini_portile2 = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1kl9c3kdchjabrihdqfmcplk3lq4cw1rr9f378y6q22qwy5dndvs";
      type = "gem";
    };
    version = "2.8.5";
  };
  minitest = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0bkmfi9mb49m0fkdhl2g38i3xxa02d411gg0m8x0gvbwfmmg5ym3";
      type = "gem";
    };
    version = "5.20.0";
  };
  msgpack = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1a5adcb7bwan09mqhj3wi9ib52hmdzmqg7q08pggn3adibyn5asr";
      type = "gem";
    };
    version = "1.7.2";
  };
  multi_json = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0pb1g1y3dsiahavspyzkdy39j4q377009f6ix0bh1ag4nqw43l0z";
      type = "gem";
    };
    version = "1.15.0";
  };
  multipart-post = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0lgyysrpl50wgcb9ahg29i4p01z0irb3p9lirygma0kkfr5dgk9x";
      type = "gem";
    };
    version = "2.3.0";
  };
  net-imap = {
    dependencies = ["date" "net-protocol"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0541lfqaz46h8s3fks11vsd1iqzmgjjw3c0jp9agg92zblwj0axs";
      type = "gem";
    };
    version = "0.4.7";
  };
  net-pop = {
    dependencies = ["net-protocol"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1wyz41jd4zpjn0v1xsf9j778qx1vfrl24yc20cpmph8k42c4x2w4";
      type = "gem";
    };
    version = "0.1.2";
  };
  net-protocol = {
    dependencies = ["timeout"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1a32l4x73hz200cm587bc29q8q9az278syw3x6fkc9d1lv5y0wxa";
      type = "gem";
    };
    version = "0.2.2";
  };
  net-smtp = {
    dependencies = ["net-protocol"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1rx3758w0bmbr21s2nsc6llflsrnp50fwdnly3ixra4v53gbhzid";
      type = "gem";
    };
    version = "0.4.0";
  };
  nio4r = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0xkjz56qc7hl7zy7i7bhiyw5pl85wwjsa4p70rj6s958xj2sd1lm";
      type = "gem";
    };
    version = "2.7.0";
  };
  nokogiri = {
    dependencies = ["mini_portile2" "racc"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "004ip9x9281fxhpipwi8di1sb1dnabscq9dy1p3cxgdwbniqqi12";
      type = "gem";
    };
    version = "1.15.5";
  };
  oj = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0m4vsd6i093kmyz9gckvzpnws997laldaiaf86hg5lza1ir82x7n";
      type = "gem";
    };
    version = "3.16.1";
  };
  pairing_heap = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15c97yvzkfhy7glsdza48sswidjyjphdx62yjapbrs5fzf0089id";
      type = "gem";
    };
    version = "3.0.1";
  };
  parallel = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0jcc512l38c0c163ni3jgskvq1vc3mr8ly5pvjijzwvfml9lf597";
      type = "gem";
    };
    version = "1.23.0";
  };
  parser = {
    dependencies = ["ast" "racc"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0r69dbh6h6j4d54isany2ir4ni4gf2ysvk3k44awi6amz18nggpd";
      type = "gem";
    };
    version = "3.2.2.4";
  };
  persistent_enum = {
    dependencies = ["activerecord" "activerecord-import" "activesupport"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1iaqckzh1j0522ah3j1f3zd0mnphr4k231iwrnk6jnll5zviw1d3";
      type = "gem";
    };
    version = "1.2.6";
  };
  pg = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0pfj771p5a29yyyw58qacks464sl86d5m3jxjl5rlqqw2m3v5xq4";
      type = "gem";
    };
    version = "1.5.4";
  };
  prism = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "172qxf1zyrhxzwbn4c7gz12zdyb1jkdqrqvb2c7863lmxp53rrxs";
      type = "gem";
    };
    version = "0.18.0";
  };
  psych = {
    dependencies = ["stringio"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0wjzrkssjfjpynij5dpycyflhqbjvi1gc2j73xgq3b196s1d3c24";
      type = "gem";
    };
    version = "5.1.1.1";
  };
  public_suffix = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1bni4qjrsh2q49pnmmd6if4iv3ak36bd2cckrs6npl111n769k9m";
      type = "gem";
    };
    version = "5.0.4";
  };
  puma = {
    dependencies = ["nio4r"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0yqv698njhwi5m8wc6smgszjswlv8ib94kkq5ih9apnsrraggzw9";
      type = "gem";
    };
    version = "5.6.7";
  };
  raabro = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "10m8bln9d00dwzjil1k42i5r7l82x25ysbi45fwyv4932zsrzynl";
      type = "gem";
    };
    version = "1.4.0";
  };
  racc = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "01b9662zd2x9bp4rdjfid07h09zxj7kvn7f5fghbqhzc625ap1dp";
      type = "gem";
    };
    version = "1.7.3";
  };
  rack = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15rdwbyk71c9nxvd527bvb8jxkcys8r3dj3vqra5b3sa63qs30vv";
      type = "gem";
    };
    version = "2.2.8";
  };
  rack-attack = {
    dependencies = ["rack"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0z6pj5vjgl6swq7a33gssf795k958mss8gpmdb4v4cydcs7px91w";
      type = "gem";
    };
    version = "6.7.0";
  };
  rack-cors = {
    dependencies = ["rack"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "02lvkg1nb4z3zc2nry545dap7a64bb9h2k8waxfz0jkabkgnpimw";
      type = "gem";
    };
    version = "2.0.1";
  };
  rack-test = {
    dependencies = ["rack"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ysx29gk9k14a14zsp5a8czys140wacvp91fja8xcja0j1hzqq8c";
      type = "gem";
    };
    version = "2.1.0";
  };
  rails = {
    dependencies = ["actioncable" "actionmailbox" "actionmailer" "actionpack" "actiontext" "actionview" "activejob" "activemodel" "activerecord" "activestorage" "activesupport" "railties"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0rsqin156dawz7gzpy1ijs02afqcr4704vqj56s6yxng3a9ayhwf";
      type = "gem";
    };
    version = "7.0.8";
  };
  rails-dom-testing = {
    dependencies = ["activesupport" "minitest" "nokogiri"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0fx9dx1ag0s1lr6lfr34lbx5i1bvn3bhyf3w3mx6h7yz90p725g5";
      type = "gem";
    };
    version = "2.2.0";
  };
  rails-html-sanitizer = {
    dependencies = ["loofah" "nokogiri"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1pm4z853nyz1bhhqr7fzl44alnx4bjachcr6rh6qjj375sfz3sc6";
      type = "gem";
    };
    version = "1.6.0";
  };
  railties = {
    dependencies = ["actionpack" "activesupport" "method_source" "rake" "thor" "zeitwerk"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0sfc16zrcn4jgf5xczb08n6prhmqqgg9f0b4mn73zlzg6cwmqchj";
      type = "gem";
    };
    version = "7.0.8";
  };
  rainbow = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0smwg4mii0fm38pyb5fddbmrdpifwv22zv3d3px2xx497am93503";
      type = "gem";
    };
    version = "3.1.1";
  };
  rake = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ilr853hawi09626axx0mps4rkkmxcs54mapz9jnqvpnlwd3wsmy";
      type = "gem";
    };
    version = "13.1.0";
  };
  rbs = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dgj5n7rj83981fvrhswfwsh88x42p7r00nvd80hkxmdcjvda2h6";
      type = "gem";
    };
    version = "2.8.4";
  };
  rdoc = {
    dependencies = ["psych"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1pnkgnk2vli1y8bbc25qbgv6z2al44dlgcm2mx3ssm34j7xz7gqh";
      type = "gem";
    };
    version = "6.6.0";
  };
  redis = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0fikjg6j12ka6hh36dxzhfkpqqmilzjfzcdf59iwkzsgd63f0ziq";
      type = "gem";
    };
    version = "4.8.1";
  };
  regexp_parser = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1d9a5s3qrjdy50ll2s32gg3qmf10ryp3v2nr5k718kvfadp50ray";
      type = "gem";
    };
    version = "2.8.2";
  };
  reline = {
    dependencies = ["io-console"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1hi6zfj6zqzxcbamhjm9w9cswv62f76l8gsdfcnmhpw35cyxphh8";
      type = "gem";
    };
    version = "0.4.1";
  };
  renum = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0lir5bhcxz19ni5bd1p78kjz2pwgwwqilacbygwds5xs2173l62w";
      type = "gem";
    };
    version = "1.4.0";
  };
  request_store = {
    dependencies = ["rack"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "13ppgmsbrqah08j06bybd3cddv6dml79yzyjn7r8j1src78h98h7";
      type = "gem";
    };
    version = "1.5.1";
  };
  reverse_markdown = {
    dependencies = ["nokogiri"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0087vhw5ik50lxvddicns01clkx800fk5v5qnrvi3b42nrk6885j";
      type = "gem";
    };
    version = "2.1.1";
  };
  rexml = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "05i8518ay14kjbma550mv0jm8a6di8yp5phzrd8rj44z9qnrlrp0";
      type = "gem";
    };
    version = "3.2.6";
  };
  rgl = {
    dependencies = ["pairing_heap" "rexml" "stream"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dji1k9knrf8cxm5psd3pgd9i8f7cfq182jwjpi1pwxw15axf496";
      type = "gem";
    };
    version = "0.6.6";
  };
  rspec-core = {
    dependencies = ["rspec-support"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0l95bnjxdabrn79hwdhn2q1n7mn26pj7y1w5660v5qi81x458nqm";
      type = "gem";
    };
    version = "3.12.2";
  };
  rspec-expectations = {
    dependencies = ["diff-lcs" "rspec-support"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "05j44jfqlv7j2rpxb5vqzf9hfv7w8ba46wwgxwcwd8p0wzi1hg89";
      type = "gem";
    };
    version = "3.12.3";
  };
  rspec-mocks = {
    dependencies = ["diff-lcs" "rspec-support"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1gq7gviwpck7fhp4y5ibljljvxgjklza18j62qf6zkm2icaa8lfy";
      type = "gem";
    };
    version = "3.12.6";
  };
  rspec-rails = {
    dependencies = ["actionpack" "activesupport" "railties" "rspec-core" "rspec-expectations" "rspec-mocks" "rspec-support"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1dpmbq2awsjiwn300cafp9fbvv86dl7zrb760anhmm1qw8yzg1my";
      type = "gem";
    };
    version = "6.1.0";
  };
  rspec-support = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ky86j3ksi26ng9ybd7j0qsdf1lpr8mzrmn98yy9gzv801fvhsgr";
      type = "gem";
    };
    version = "3.12.1";
  };
  rubocop = {
    dependencies = ["json" "language_server-protocol" "parallel" "parser" "rainbow" "regexp_parser" "rexml" "rubocop-ast" "ruby-progressbar" "unicode-display_width"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "10y1p3y37jrvp0wbjxcs00px71998j6p3srqpv34czvmgdgsknv8";
      type = "gem";
    };
    version = "1.58.0";
  };
  rubocop-ast = {
    dependencies = ["parser"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1cs9cc5p9q70valk4na3lki4xs88b52486p2v46yx3q1n5969bgs";
      type = "gem";
    };
    version = "1.30.0";
  };
  rubocop-iknow = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0c8f8kj585gmiz1x9yjaxadc6m26lsnz81kir56c6znd2vjrbwjk";
      type = "gem";
    };
    version = "0.0.12";
  };
  rubocop-rails = {
    dependencies = ["activesupport" "rack" "rubocop" "rubocop-ast"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0ym0h2w97b8c2h6zl44m22lzg253qkmim0ali32aiy58ddvbj0mm";
      type = "gem";
    };
    version = "2.22.2";
  };
  ruby-lsp = {
    dependencies = ["language_server-protocol" "prism" "sorbet-runtime"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "13snp4q09vv3g7nskaza9xm50shxrdc2xxdyz6gp4vgzbvp4ihc0";
      type = "gem";
    };
    version = "0.13.0";
  };
  ruby-progressbar = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0cwvyb7j47m7wihpfaq7rc47zwwx9k4v7iqd9s1xch5nm53rrz40";
      type = "gem";
    };
    version = "1.13.0";
  };
  ruby2_keywords = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1vz322p8n39hz3b4a9gkmz9y7a5jaz41zrm2ywf31dvkqm03glgz";
      type = "gem";
    };
    version = "0.0.5";
  };
  safe_values = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0zd6k706ql8blcs44bc84s6ld1sh4d546r80x16c6qc3sc3as7gx";
      type = "gem";
    };
    version = "1.0.2";
  };
  solargraph = {
    dependencies = ["backport" "benchmark" "diff-lcs" "e2mmap" "jaro_winkler" "kramdown" "kramdown-parser-gfm" "parser" "rbs" "reverse_markdown" "rubocop" "thor" "tilt" "yard"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "18wpma2mgw82qzf1jwjalmz7nwdvn87b22wd5yy16jb67fqgrq78";
      type = "gem";
    };
    version = "0.49.0";
  };
  sorbet-runtime = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "18280l1wgdmr9xhr4mzxr4ycskwbgjzd91vmdzx0dlp6xp2dydnb";
      type = "gem";
    };
    version = "0.5.11144";
  };
  sprockets = {
    dependencies = ["concurrent-ruby" "rack"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "15rzfzd9dca4v0mr0bbhsbwhygl0k9l24iqqlx0fijig5zfi66wm";
      type = "gem";
    };
    version = "4.2.1";
  };
  sprockets-rails = {
    dependencies = ["actionpack" "activesupport" "sprockets"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1b9i14qb27zs56hlcc2hf139l0ghbqnjpmfi0054dxycaxvk5min";
      type = "gem";
    };
    version = "3.4.2";
  };
  stream = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "016m9v81vpj14d8g5ins91zc4pzl7vf5f1gxl7jhfsfy601k7cv2";
      type = "gem";
    };
    version = "0.5.5";
  };
  stringio = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "063psvsn1aq6digpznxfranhcpmi0sdv2jhra5g0459sw0x2dxn1";
      type = "gem";
    };
    version = "3.1.0";
  };
  thor = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1hx77jxkrwi66yvs10wfxqa8s25ds25ywgrrf66acm9nbfg7zp0s";
      type = "gem";
    };
    version = "1.3.0";
  };
  tilt = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0p3l7v619hwfi781l3r7ypyv1l8hivp09r18kmkn6g11c4yr1pc2";
      type = "gem";
    };
    version = "2.3.0";
  };
  timeout = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "16mvvsmx90023wrhf8dxc1lpqh0m8alk65shb7xcya6a9gflw7vg";
      type = "gem";
    };
    version = "0.4.1";
  };
  typhoeus = {
    dependencies = ["ethon"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0z7gamf6s83wy0yqms3bi4srirn3fc0lc7n65lqanidxcj1xn5qw";
      type = "gem";
    };
    version = "1.4.1";
  };
  tzinfo = {
    dependencies = ["concurrent-ruby"];
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "16w2g84dzaf3z13gxyzlzbf748kylk5bdgg3n1ipvkvvqy685bwd";
      type = "gem";
    };
    version = "2.0.6";
  };
  unicode-display_width = {
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1d0azx233nags5jx3fqyr23qa2rhgzbhv8pxp46dgbg1mpf82xky";
      type = "gem";
    };
    version = "2.5.0";
  };
  web-console = {
    dependencies = ["actionview" "activemodel" "bindex" "railties"];
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "087y4byl2s3fg0nfhix4s0r25cv1wk7d2j8n5324waza21xg7g77";
      type = "gem";
    };
    version = "4.2.1";
  };
  webmock = {
    dependencies = ["addressable" "crack" "hashdiff"];
    groups = ["development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0vfispr7wd2p1fs9ckn1qnby1yyp4i1dl7qz8n482iw977iyxrza";
      type = "gem";
    };
    version = "3.19.1";
  };
  websocket-driver = {
    dependencies = ["websocket-extensions"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1nyh873w4lvahcl8kzbjfca26656d5c6z3md4sbqg5y1gfz0157n";
      type = "gem";
    };
    version = "0.7.6";
  };
  websocket-extensions = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0hc2g9qps8lmhibl5baa91b4qx8wqw872rgwagml78ydj8qacsqw";
      type = "gem";
    };
    version = "0.1.5";
  };
  yard = {
    groups = ["development"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "013yrnwx1zhzhn1fnc19zck22a1qgimsaglp2iwgf5bz9l8h93js";
      type = "gem";
    };
    version = "0.9.34";
  };
  zeitwerk = {
    groups = ["default" "development" "test"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1gir0if4nryl1jhwi28669gjwhxb7gzrm1fcc8xzsch3bnbi47jn";
      type = "gem";
    };
    version = "2.6.12";
  };
}

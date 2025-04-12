from pathlib import Path
try:
    import yaml
    cfg = yaml.load(open(Path.home() / '.ets.yml'))
except Exception as e:
    print("Could not read yaml: {}".format(e))
else:
    try:
        from box import Box
        cfg = Box(cfg)
    except Exception as e:
        print("Could not convert cfg into box: {}".format(e))

try:
    import tourbillon_client
except:
    pass

try:
    from safires import sf, CFG
    bs = sf.bs.preprod
except:
    pass

try:
    import bluesnake
except Exception as e:
    print("Could not import bluesnake")

try:
    from octopus.core.clients.meteomatics import MeteomaticsClient
    meteoclient = MeteomaticsClient(username=cfg.meteomatics.username,
                                    password=cfg.meteomatics.password)
    locations = (50.403611, 3.728056)
except Exception as e:
    print(e)

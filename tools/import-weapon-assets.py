"""Import the user's weapon wiki index and local inventory illustrations.
Run with --fetch to download; --check validates the committed catalogue/images.
Requires beautifulsoup4 for import, standard library only for --check.
Native record evidence comes from Open77 Devkit weapons catalogue 2.31.
"""
from pathlib import Path
import argparse, concurrent.futures, hashlib, json, re, time, unicodedata, urllib.request
ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'resources/gamemodes/op77_lightrp/catalogues/armament'
IMAGES=ROOT/'ui/public/img/items'
CATALOGUE=DATA/'weapon-catalogue.json'
SOURCE='https://cyberpunk.fandom.com/wiki/Cyberpunk_2077_Weapons'
API='https://cyberpunk.fandom.com/api.php?action=parse&page=Cyberpunk_2077_Weapons&prop=text&format=json'
OVERRIDES={'Tamayura':'Items.Preset_Nue_Arasaka_2077','Slaught-O-Matic':'Items.Preset_Base_Slaughtomatic',"Chef's Knife":'Items.Preset_Chefs_Knife_Default','Fang':'Items.Preset_Knife_Kurtz_1'}
IDS={'3516':'weapon_malorian_arms_3516','M-10AF Lexington':'weapon_lexington','Nue':'weapon_nue','F-GX Frag Grenade':'grenade_frag','EMP Grenade':'grenade_emp','CHAR Incendiary Grenade':'grenade_incendiary','MOLODETS BioHaz Grenade':'grenade_biohazard','GASH Antipersonnel Grenade':'grenade_cutting','Recon Grenade':'grenade_recon','Smoke Grenade':'grenade_smoke','X-22 Flashbang Grenade':'grenade_flashbang',"Ozob's Nose":'grenade_ozobs_nose'}
def fetch(url):
    for attempt in range(3):
        try:
            req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0' if 'static.wikia.nocookie.net' in url else 'Open77InventoryAssetImporter/1.0','Referer':'https://cyberpunk.fandom.com/','Accept':'image/png,application/json,text/html;q=0.9,*/*;q=0.8'})
            with urllib.request.urlopen(req,timeout=30) as response:return response.read()
        except Exception:
            if attempt==2:raise
            time.sleep(attempt+1)
def slug(s):return re.sub('[^a-z0-9]+','_',unicodedata.normalize('NFKD',s).encode('ascii','ignore').decode().lower()).strip('_')
def validate():
    catalogue=json.loads(CATALOGUE.read_text());rows=catalogue['items'];assert len(rows)==catalogue['count']
    assert len({x['itemId']for x in rows})==len(rows)
    native={r['record']:r for r in json.loads((DATA/'native-weapons-2.31.json').read_text())['rows']}
    for x in rows:
        p=IMAGES/Path(x['image']).name
        assert p.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'),str(p)
        assert hashlib.sha256(p.read_bytes()).hexdigest()==x['sha256'],str(p)
        assert re.fullmatch(r'(weapon|grenade)_[a-z0-9_]+',x['itemId'])
        if x['record']:assert x['record']in native,x['record']
    print(f"PASS: {len(rows)} unique items/images; {sum(bool(x['record'])for x in rows)} verified native records; no remote runtime URLs")
def main():
    p=argparse.ArgumentParser();p.add_argument('--fetch',action='store_true');p.add_argument('--check',action='store_true');p.add_argument('--cache',type=Path,help='Optional saved MediaWiki parse JSON for reproducible imports');args=p.parse_args()
    if args.check:validate();return
    if not args.fetch:p.error('choose --fetch or --check')
    from bs4 import BeautifulSoup
    payload=args.cache.read_bytes() if args.cache else fetch(API)
    page=json.loads(payload)['parse'];soup=BeautifulSoup(page['text']['*'],'html.parser')
    native={x['record']:x for x in json.loads((DATA/'native-weapons-2.31.json').read_text())['rows']};by_lower={k.lower():k for k in native}
    rows=[]
    for table in soup.select('table.fandom-table'):
        heading=table.find_previous(['h2','h3']).get_text(' ',strip=True).replace(' [ ]','')
        for tr in table.select('tr')[1:]:
            cells=tr.find_all(['td','th'],recursive=False)
            if len(cells)<2:continue
            link=cells[1].find('a',href=lambda s:s and s.startswith('/wiki/'));image=cells[0].find('img')
            if not link or not image:raise ValueError('Expected a named weapon with an image')
            name=cells[1].get_text(' ',strip=True)
            if name=='3516':name='Malorian Arms 3516'
            if name=='Crowbar' and image.get('data-image-name')=='Crowbar Bunker.png':name='Bunker Crowbar'
            kind='grenade'if heading=='Grenades'else'weapon'
            item_id=IDS.get(name,kind+'_'+slug(name))
            image_name=image['data-image-name'];stem=image_name.rsplit('.',1)[0].replace(' ','_')
            record=OVERRIDES.get(name) or next((by_lower[k.lower()]for k in ['Items.Preset_'+stem,'Items.'+stem]if k.lower()in by_lower),None)
            row={'itemId':item_id,'label':name,'category':heading,'kind':kind,'record':record,'nativeItemType':native[record].get('itemType')if record else None,
                 'recordEvidence':'reviewed_alias'if name in OVERRIDES else'image_filename_exact'if record else'unresolved',
                 'image':'img/items/'+item_id+'.png','sourcePage':'https://cyberpunk.fandom.com'+link['href'],
                 'sourceImage':re.sub(r'/scale-to-width-down/\d+','/scale-to-width-down/256',image.get('data-src',image.get('src')))+'&format=original','sourceImageName':image_name,
                 'integrationStatus':'implemented'if item_id in ['weapon_lexington','weapon_nue']else'needs_native_record'if not record else'catalogued_not_enabled'}
            rows.append(row)
    assert len({r['itemId']for r in rows})==len(rows)
    IMAGES.mkdir(parents=True,exist_ok=True)
    def download(row):
        path=IMAGES/(row['itemId']+'.png')
        data=path.read_bytes()if path.exists()else fetch(row['sourceImage'])
        if not data.startswith(b'\x89PNG\r\n\x1a\n'):raise ValueError('Not a PNG: '+row['itemId'])
        path.write_bytes(data);row['sha256']=hashlib.sha256(data).hexdigest();row['bytes']=len(data)
        return row['itemId']
    with concurrent.futures.ThreadPoolExecutor(max_workers=6)as pool:
        for n,name in enumerate(pool.map(download,rows),1):
            if n%25==0 or n==len(rows):print(f'Downloaded {n}/{len(rows)}: {name}',flush=True)
    CATALOGUE.write_text(json.dumps({'schemaVersion':1,'sourcePage':SOURCE,'sourcePageId':page['pageid'],'nativeCatalogueBuild':'2.31','count':len(rows),'items':rows},ensure_ascii=False,indent=2)+'\n')
    validate()
if __name__=='__main__':main()

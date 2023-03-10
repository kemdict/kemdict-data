.ONESHELL:
.DEFAULT_GOAL := build

export LANG=en_US.UTF-8

admin.deploy: entries.db.gz
	@[ "$$SSH_HOST"x != x ] || (echo 'Please specify $$SSH_HOST'; exit 1)
	rsync entries.db.gz "$$SSH_HOST:/home/kisaragi/deployed/kemdict.db.gz"
	ssh "$$SSH_HOST" bash << HERE
	  gzip -d -f deployed/kemdict.db.gz
	  systemctl restart --user kemdict
	HERE

build: entries.db
.PHONY: build

.cask: Cask
	cask install
	touch .cask

node_modules: package.json
	npm install

DICT_TARGETS := moedict-data-twblg/dict-twblg.json
DICT_TARGETS += kisaragi/kisaragi_dict.json
DICT_TARGETS += kisaragi/extra-strokes.json
DICT_TARGETS += ministry-of-education/package.json
DICT_TARGETS += chhoetaigi/ChhoeTaigi_iTaigiHoataiTuichiautian.json
DICT_TARGETS += chhoetaigi/ChhoeTaigi_TaijitToaSutian.json
DICT_TARGETS += chhoetaigi/ChhoeTaigi_TaioanPehoeKichhooGiku.json

dicts: $(DICT_TARGETS)
.PHONY: dicts

heteronyms.json: $(DICT_TARGETS) process-data.el .cask node_modules
	cask eval "(load \"process-data\")"

entries.db: heteronyms.json heteronyms-to-sqlite.mjs
	node heteronyms-to-sqlite.mjs

entries.db.gz: entries.db
	gzip --keep --force entries.db
	touch entries.db.gz

kisaragi/kisaragi_dict.json: kisaragi/kisaragi-dict.org kisaragi/generate.el .cask
	cask eval "(load \"kisaragi/generate\")"

# I'm picking kip (department of education) for now because
# 1. I treat it as just a spelling reform
# 2. this makes it consistent when MOE's Taigi dictionary is also displayed
# but this is frankly questionable.
# TODO: I'll revisit this later.
# FIXME: I'm also just throwing away PojUnicodeOthers when it contains
# alternative pronunciations.
#
# - HanLoTaibunPoj -> title, because I've assumed that each entry has
#   a main title and I need to pick one. It's not an ideal assumption.
# - HuaBun -> definition, again because of Kemdict's assumptions.
# - Dropping the Input columns -- which use numbers to represent tones,
#   not unicode sequences -- because they're not needed.
# - The original header is (without the newline):
#     "DictWordID","PojUnicode","PojInput","KipUnicode","KipInput",
#     "HanLoTaibunPoj","HanLoTaibunKip","HoaBun","DataProvidedBy"
chhoetaigi/ChhoeTaigi_iTaigiHoataiTuichiautian.json: ChhoeTaigiDatabase/README.md
	mkdir -p chhoetaigi
	npx csvtojson --ignoreColumns='/Input/' --headers='["id","poj","PojInput","kip","KipInput","title","HanLoTaibunKip","definition","DataProvidedBy"]' ChhoeTaigiDatabase/ChhoeTaigiDatabase/ChhoeTaigi_iTaigiHoataiTuichiautian.csv > "$@"

# Original header:
# "DictWordID","PojUnicode","PojUnicodeOthers","PojInput","PojInputOthers","HanLoTaibunPoj","KaisoehHanLoPoj","LekuHanLoPoj","KipUnicode","KipUnicodeOthers","KipInput","KipInputOthers","HanLoTaibunKip","KaisoehHanLoKip","LekuHanLoKip","PageNumber","GoanchhehPoochhiongChuliau"
# HanLoTaibunPoj -> title
# KaisoehHanLoPoj -> definition
# LekuHanLoKip -> example
chhoetaigi/ChhoeTaigi_TaijitToaSutian.json: ChhoeTaigiDatabase/README.md
	mkdir -p chhoetaigi
	npx csvtojson --ignoreColumns='/Input|Page|Others|Goanchheh/' --headers='["id","poj","PojUnicodeOthers","PojInput","PojInputOthers","title","definition","example","kip","KipUnicodeOthers","KipInput","KipInputOthers","HanLoTaibunKip","KaisoehHanLoKip","LekuHanLoKip","PageNumber","GoanchhehPoochhiongChuliau"]' ChhoeTaigiDatabase/ChhoeTaigiDatabase/ChhoeTaigi_TaijitToaSutian.csv > "$@"

# 1956 ????????????????????????
# Original header:
# "DictWordID","PojUnicode","PojUnicodeOthers","PojInput","PojInputOthers","KipUnicode","KipUnicodeOthers","KipInput","KipInputOthers","HoaBun","EngBun","KaisoehEngbun","NounClassifier","LesuPoj","Opposite","LekuPoj","LekuEngbun","LekuHoabun","Confer","PageNumber"
#
# We don't add another title. We'll copy props.poj to props.title in
# process-data.
chhoetaigi/ChhoeTaigi_TaioanPehoeKichhooGiku.json: ChhoeTaigiDatabase/README.md
	mkdir -p chhoetaigi
	npx csvtojson --ignoreColumns='/Input|Page|Others/' --headers='["id","poj","PojUnicodeOthers","PojInput","PojInputOthers","kip","KipUnicodeOthers","KipInput","KipInputOthers","zh","en","descEn","NounClassifier","??????POJ","antonym","examplePOJ","exampleEn","exampleZh","??????","PageNumber"]' ChhoeTaigiDatabase/ChhoeTaigiDatabase/ChhoeTaigi_TaioanPehoeKichhooGiku.csv > "$@"

# Automatic submodule fetching. The specified file is just used to
# mark whether the submodule has been populated or not.
moedict-data-twblg/dict-twblg.json:
	git submodule update --init --depth 1 -- moedict-data-twblg

ministry-of-education/package.json:
	git submodule update --init --depth 1 -- ministry-of-education

ChhoeTaigiDatabase/README.md:
	git submodule update --init --depth 1 -- ChhoeTaigiDatabase

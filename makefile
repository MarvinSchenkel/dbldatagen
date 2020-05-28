.PHONY: clean wheel dist tests buildenv install

NO_COLOR = \x1b[0m
OK_COLOR = \x1b[32;01m
ERROR_COLOR = \x1b[31;01m

PYCACHE := $(shell find . -name '__pycache__')
EGGS :=  $(shell find . -name '*.egg-info')
CURRENT_VERSION := $(shell awk '/current_version/ {print $$3}' python/.bumpversion.cfg)

clean:
	@echo "$(OK_COLOR)=> Cleaning$(NO_COLOR)"
	@echo "Current version: $(CURRENT_VERSION)"
	@rm -fr build dist $(EGGS) $(PYCACHE) databrickslabs_testdatagenerator/lib/* databrickslabs_testdatagenerator/env_files/*


prepare: clean
	@echo "$(OK_COLOR)=> Preparing ...$(NO_COLOR)"
	git add .
	git status
	git commit -m "cleanup before release"

build_env/bin/activate: python/require.txt
	@echo "$(OK_COLOR)=> Updating build virtual environment ...$(NO_COLOR)"
	@test -d build_env || python3 -m venv build_env
	@. build_env/bin/activate; pip install -Ur python/require.txt
	@touch build_env/bin/activate

buildenv: build_env/bin/activate
	@echo "$(OK_COLOR)=> Checking build virtual environment ...$(NO_COLOR)"

describe_buildenv: buildenv
	@echo "$(OK_COLOR)=> Validating build virtual environment ...$(NO_COLOR)"
	@echo "The following packages are installed:"
	@source `pwd`/build_env/bin/activate; pip3 list

clean_buildenv:
	@echo "$(OK_COLOR)=> Cleaning build virtual environment ...$(NO_COLOR)"
	@rm -rf ./build_env
	@echo "directory is `pwd`"
	@echo "$(OK_COLOR)=> Creating build virtual environment ...$(NO_COLOR)"
	@python3 -m venv build_env
	@. build_env/bin/activate; pip install -r python/require.txt



# Tests

# setup exports for build on mac osx
tests: export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
#tests: export PYSPARK_PYTHON=`which python3`
#tests: export PYSPARK_DRIVER_PYTHON=`which python3`

tests: buildenv dist/install_flag.txt
	@echo "$(OK_COLOR)=> Running unit tests$(NO_COLOR)"
	. `pwd`/build_env/bin/activate; python3 -m unittest discover -s "unit_tests" -p "*.py"

# Version commands

bump:
ifdef part
ifdef version
	@. `pwd`/build_env/bin/activate; \
	bumpversion --config-file python/.bumpversion.cfg --allow-dirty --new-version $(version) $(part) ; \
	grep current python/.bumpversion.cfg ; \
	grep -H version setup.py ; \
	grep -H "Version" RELEASE_NOTES.md
else
	. `pwd`/build_env/bin/activate; bumpversion --config-file python/.bumpversion.cfg --allow-dirty $(part) ; \
	grep current python/.bumpversion.cfg ; \
	grep -H "version" setup.py ; \
	grep -H "Version" RELEASE_NOTES.md
endif
else
	@echo "$(ERROR_COLOR)Provide part=major|minor|patch|release|build and optionally version=x.y.z...$(NO_COLOR)"
	exit 1
endif

# Dist commands

# wheel:

dist: buildenv
	@echo "$(OK_COLOR)=> building dist of wheel$(NO_COLOR)"
	@source `pwd`/build_env/bin/activate; python3 setup.py sdist bdist_wheel
	@touch `pwd`/dist/dist_flag.txt

dist/dist_flag.txt: dist

release:
	git add .
	git status
	#git commit -m "Latest release: $(CURRENT_VERSION)"
	#git tag -a v$(CURRENT_VERSION) -m "Latest release: $(CURRENT_VERSION)"

install: buildenv dist/dist_flag.txt
	@echo "$(OK_COLOR)=> Installing databrickslabs_testdatagenerator$(NO_COLOR)"
	@cp README.md python/
	@source `pwd`/build_env/bin/activate; pip3 install --upgrade .
	@touch `pwd`/dist/install_flag.txt

dist/install_flag.txt: install


# dev tools

check_version:
	dev_tools/check_versions env.yml

dev_tools:
	pip install --upgrade bumpversion
	pip3 install --upgrade bumpversion
	python3 -m pip install --user --upgrade yapf pylint pyYaml
	python3 -m pip install --user --upgrade setuptools wheel
import std/[os, options, tables], private/library

type
  AllegroConfig* = ptr object
  AllegroConfigEntry = ptr object
  AllegroConfigSection = ptr object

{.push importc, dynlib: library.allegro.}
proc al_create_config(): AllegroConfig
proc al_load_config_file(filename: cstring): AllegroConfig
proc al_destroy_config(config: AllegroConfig): void

proc al_save_config_file(filename: cstring, config: AllegroConfig): bool

proc al_add_config_section(config: AllegroConfig, name: cstring): void
proc al_remove_config_section(config: AllegroConfig, section: cstring): bool
proc al_add_config_comment(config: AllegroConfig, section, comment: cstring): void

proc al_get_config_value(config: AllegroConfig, section, key: cstring): cstring
proc al_set_config_value(config: AllegroConfig, section, key, value: cstring): void
proc al_remove_config_key(config: AllegroConfig, section, key: cstring): bool

proc al_get_first_config_section(config: AllegroConfig, configSection: ref AllegroConfigSection): cstring
proc al_get_next_config_section(configSection: ref AllegroConfigSection): cstring

proc al_get_first_config_entry(config: AllegroConfig, section: cstring, configEntry: ref AllegroConfigEntry): cstring
proc al_get_next_config_entry(configEntry: ref AllegroConfigEntry): cstring

proc al_merge_config(cfg1, cfg2: AllegroConfig): AllegroConfig
proc al_merge_config_into(master, add: AllegroConfig): void
{.pop.}

#[
  Create an empty configuration structure.
]#
proc newAllegroConfig*(): AllegroConfig =
  return al_create_config()

#[
  Read a configuration file from disk or create an empty.
]#
proc newAllegroConfig*(filename: string): AllegroConfig =
  if os.fileExists filename:
    return al_load_config_file(filename)
  return al_create_config()

#[
  Free the resources used by a configuration structure.
]#
proc free*(config: AllegroConfig): void =
  al_destroy_config(config)

#[
  Write out a configuration file to disk.
]#
proc save*(config: AllegroConfig, filename: string): void =
  discard al_save_config_file(filename, config)

#[
  Add a section to a configuration structure with the given name.
  If the section already exists then nothing happens.
]#
proc addSection*(config: AllegroConfig, name: string): void =
  al_add_config_section(config, name)

#[
  Remove a section of a configuration.
]#
proc removeSection*(config: AllegroConfig, section: string): void =
  discard al_remove_config_section(config, section)

#[
  Add a comment in a section of a configuration. If the section doesn’t yet exist, it will be created. The section can be "" for the global section.
  The comment may or may not begin with a hash character. Any newlines in the comment string will be replaced by space characters.
]#
proc addComment*(config: AllegroConfig, section, comment: string): void =
  al_add_config_comment(config, section, comment)

#[]#
proc value*(config: AllegroConfig, section, key: string): Option[string] =
  var value = al_get_config_value(config, section, key)
  if value.isNil:
    return none(string)
  return some($value)

#[
  Set a value in a section of a configuration. If the section doesn’t yet exist, it will be created.
  If a value already existed for the given key, it will be overwritten. The section can be "" for the global section.
  For consistency with the on-disk format of config files, any leading and trailing whitespace will be stripped from the value.
  If you have significant whitespace you wish to preserve, you should add your own quote characters and remove them when reading the values back in.
]#
proc value*(config: AllegroConfig, section, key, value: string): void =
  al_set_config_value(config, section, key, value)

#[
  Remove a key and its associated value in a section of a configuration.
]#
proc removeKey*(config: AllegroConfig, section, key: string): void =
  discard al_remove_config_key(config, section, key)

#[
  Merge one configuration structure into another.
  Values in configuration ‘add’ override those in ‘master’.
  ‘master’ is modified. Comments from ‘add’ are not retained.
]#
proc merge*(master, add: AllegroConfig): void =
  al_merge_config_into(master, add)

#[
  Merge two configuration structures, and return the result as a new configuration.
  Values in configuration ‘cfg2’ override those in ‘cfg1’.
  Neither of the input configuration structures are modified.
  Comments from ‘cfg2’ are not retained.
]#
proc `+`*(cfg1, cfg2: AllegroConfig): AllegroConfig =
  al_merge_config(cfg1, cfg2)

#[]#
iterator sections*(config: AllegroConfig): string =
  var section = new AllegroConfigSection
  var sectionName = al_get_first_config_section(config, section)
  while not sectionName.isNil:
    yield $sectionName
    sectionName = al_get_next_config_section(section)

#[]#
iterator entries*(config: AllegroConfig, section: string): string =
  var entry = new AllegroConfigEntry
  var entryName = al_get_first_config_entry(config, section, entry)
  while not entryName.isNil:
    yield $entryName
    entryName = al_get_next_config_entry(entry)

#[]#
proc `[]`*(config: AllegroConfig, section: string): TableRef[string, string] =
  var values = newTable[string, string]()
  for entry in config.entries(section):
    values[entry] = config.value(section, entry).get()
  return values

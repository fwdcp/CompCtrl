# vim: set ts=8 sts=2 sw=2 tw=99 et:
import re
import os, sys
import subprocess

argv = sys.argv[1:]
if len(argv) < 2:
  sys.stderr.write('Usage: generate_headers.py <source_path> <output_folder>\n')
  sys.exit(1)

SourceFolder = os.path.abspath(os.path.normpath(argv[0]))
OutputFolder = os.path.normpath(argv[1])

def run_and_return(argv):
  # Python 2.6 doesn't have check_output.
  if hasattr(subprocess, 'check_output'):
    text = subprocess.check_output(argv)
    if str != bytes:
      text = str(text, 'utf-8')
  else:
    p = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, ignored = p.communicate()
    rval = p.poll()
    if rval:
      raise subprocess.CalledProcessError(rval, argv)
    text = output.decode('utf8')
  return text.strip()

def get_git_version():
  revision_count = run_and_return(['git', 'rev-list', '--count', 'HEAD'])
  revision_hash = run_and_return(['git', 'log', '--pretty=format:%h:%H', '-n', '1'])
  shorthash, longhash = revision_hash.split(':')

  return revision_count, shorthash, longhash

def output_version_headers():
  rev, abbvcset, cset = get_git_version()

  with open(os.path.join(SourceFolder, 'product.version')) as fp:
    contents = fp.read()
  m = re.match('(\d+)\.(\d+)\.(\d+)-?(.*)', contents)
  if m == None:
    raise Exception('Could not detremine product version')
  major, minor, release, tag = m.groups()
  fullstring = "{0}.{1}.{2}".format(major, minor, release)
  if tag != "":
    fullstring += "-{0}".format(tag)
    if tag == "dev":
      fullstring += "+{0}".format(abbvcset)

  with open(os.path.join(OutputFolder, 'version_auto.h'), 'w') as fp:
    fp.write("""
#ifndef _EXT_AUTO_VERSION_INFORMATION_H_
#define _EXT_AUTO_VERSION_INFORMATION_H_

#define EXT_BUILD_TAG		\"{0}\"
#define EXT_BUILD_CSET		\"{1}\"
#define EXT_BUILD_MAJOR		\"{2}\"
#define EXT_BUILD_MINOR		\"{3}\"
#define EXT_BUILD_RELEASE	\"{4}\"
#define EXT_BUILD_LOCAL_REV	\"{5}\"

#define EXT_BUILD_UNIQUEID EXT_BUILD_LOCAL_REV \":\" EXT_BUILD_CSET

#define EXT_VERSION_STRING	\"{6}\"
#define EXT_VERSION_FILE	{2},{3},{4},0

#endif /* _EXT_AUTO_VERSION_INFORMATION_H_ */
    """.format(tag, cset, major, minor, release, rev, fullstring))

output_version_headers()

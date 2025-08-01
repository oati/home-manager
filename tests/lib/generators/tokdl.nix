{ lib, ... }:

{
  home.file."tokdl-result.txt".text = lib.hm.generators.toKDL { } {
    a = 1;
    b = "string";
    c = ''
      multiline string
      with special characters:
      \t \n \" "
    '';
    unsafeString = " \" \n 	 ";
    flatItems = [
      1
      2
      "asdf"
      true
      null
    ];
    bigFlatItems = [
      23847590283751
      1.239
      ''
        multiline " " "
        string
      ''
      null
    ];
    nested = [
      [
        1
        2
      ]
      [
        true
        false
      ]
      [ ]
      [ null ]
    ];
    duplicateChildren._children = [
      { child = [ 2 ]; }
      { child = [ 1 ]; }
    ];
    extraAttrs = {
      _args = [
        2
        true
      ];
      _props = {
        arg1 = 1;
        arg2 = false;
      };
      nested = {
        a = 1;
        b = null;
      };
    };
    argsAndProps = {
      _args = [
        1
        2
      ];
      _props = {
        a = 3;
      };
    };
    listInAttrsInList = {
      list1 = [
        { a = 1; }
        { b = true; }
        {
          c = null;
          d = [ { e = "asdfadfasdfasdf"; } ];
        }
      ];
      list2 = [ { a = 8; } ];
    };
  };

  nmt.script = ''
    assertFileContent \
      home-files/tokdl-result.txt \
      ${./tokdl-result.txt}
  '';
}

# The visible options of the module form the interface of the script,
# hidden ones (e.g., renamed or deprecated) and internal ones are left out at any depth.
lib: rec {
  isInterface = opt: lib.isOption opt && opt.visible or true != false && !(opt.internal or false);

  interfaceOptions = lib.filterAttrs (_: isInterface);

  # The config restricted to the interface options.
  toInterface =
    options:
    lib.concatMapAttrs (
      name: value:
      let
        opt = options.${name};
        sub = opt.type.getSubOptions [ ];
      in
      lib.optionalAttrs (isInterface opt) {
        ${name} =
          if sub == { } then
            value
          else if opt.type.name == "attrsOf" then
            lib.mapAttrs (_: toInterface sub) value
          else
            toInterface sub value;
      }
    );

  # The types of the interface options, in the format of `docker-manifest --schema`.
  toSchema =
    type:
    {
      str = "str";
      bool = "bool";
      # Packages are serialized as their store paths.
      package = "str";
      anything = "any";
      enum.enum = lib.sort lib.lessThan type.functor.payload.values;
      nullOr.nullable = toSchema type.nestedTypes.elemType;
      listOf.list = toSchema type.nestedTypes.elemType;
      attrsOf.dict = toSchema type.nestedTypes.elemType;
      submodule.object = lib.mapAttrs (_: opt: toSchema opt.type) (
        interfaceOptions (type.getSubOptions [ ])
      );
    }
    .${type.name} or (throw "flocken: the option type `${type.name}` has no schema");
}

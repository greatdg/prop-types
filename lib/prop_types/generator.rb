module PropTypes
  class Generator
    def initialize(example_props)
      @example_props = example_props
    end

    def to_js
      @to_js ||= generate_code(@example_props)
    end

    private

    ANY_PROP_TYPE = "React.PropTypes.any"
    BOOL_PROP_TYPE = "React.PropTypes.bool.isRequired"
    NUMBER_PROP_TYPE = "React.PropTypes.number.isRequired"
    STRING_PROP_TYPE = "React.PropTypes.string.isRequired"

    def generate_code(props)
      object_cache = {}
      base_shape = generate_prop_type(nil, props, 1, object_cache)
      object_cache.values.reverse.each do |cached_shape|
        if cached_shape.uses_count == 1
          base_shape = base_shape.sub(cached_shape.id, cached_shape.prop_type)
        else
          base_shape = base_shape.gsub(cached_shape.id, cached_shape.name)
          base_shape = "#{cached_shape.to_var}\n\n#{base_shape}"
        end
      end
      base_shape
    end

    # Can't do functions
    # Can't tell if required or not
    # Assumes arrays are continued list of same type
    # Thinks that `nil` is `any`
    def generate_prop_type(key_name, props, current_depth, object_cache)
      case props
      when String
        STRING_PROP_TYPE
      when NilClass
        ANY_PROP_TYPE
      when Numeric
        NUMBER_PROP_TYPE
      when TrueClass, FalseClass
        BOOL_PROP_TYPE
      when Array
        # this is wrong - it should do `shape()` if it's not a shape-name
        "React.PropTypes.arrayOf(" + generate_prop_type(nil, props[0], current_depth, object_cache) + ").isRequired"
      when Hash
        prop_type = hash_to_prop_type(props, current_depth, object_cache)
        cache_key = props.keys.sort.join(",")
        cached_shape = object_cache[cache_key] ||= begin
          PropTypes::CachedShape.new(nil, prop_type, props)
        end
        key_name && cached_shape.offer_name("#{key_name}Shape")
        cached_shape.increment
        cached_shape.id + ".isRequired"
      else
        raise "Can't generate prop for #{props} (#{props.class})"
      end
    end

    def hash_to_prop_type(props, current_depth, object_cache)
      own_indent = PropTypes::Indent.create(current_depth - 1)
      next_indent = PropTypes::Indent.create(current_depth)
      keys = props.keys.sort

      "React.PropTypes.shape({" +
        keys.map { |key|
          next_indent +
          "#{key}: " +
          generate_prop_type(key, props[key], current_depth + 1, object_cache)
        }.join(",") +
      own_indent + "})"
    end
  end
end

# Advanced Character Encoding Handling in Logstash

The Logstash pipeline in this project includes character encoding handling to process syslog entries that may contain binary data or non-UTF-8 characters. This is particularly important for security logs that might include attack payloads or malformed input.

## How It Works

The pipeline uses a Ruby filter to properly handle character encoding:

```ruby
ruby {
  code => "
    event.get('message').force_encoding('ISO-8859-1').encode!('UTF-8', :invalid => :replace, :undef => :replace, :replace => '?')
  "
}
```

This filter:
1. Gets the 'message' field from each event
2. Forces the encoding to ISO-8859-1 (Latin-1), which can represent all byte values without errors
3. Converts the text to UTF-8, replacing any invalid or undefined characters with question marks
4. Modifies the string in place for efficiency

## Why This Is Important

Security logs often contain binary data, especially when logging potential attacks such as:
- Buffer overflow attempts
- SQL injection with binary payloads
- Malicious requests with non-printable characters
- Logs with mixed encodings from various sources

Without proper encoding handling, Logstash might:
- Drop valuable security information
- Fail to process logs correctly
- Generate excessive warnings
- In extreme cases, halt the pipeline

## Customizing the Encoding Handling

If you need to modify the encoding behavior:

### Change the Replacement Character

If you want to use a different replacement character:

```ruby
ruby {
  code => "
    event.get('message').force_encoding('ISO-8859-1').encode!('UTF-8', :invalid => :replace, :undef => :replace, :replace => '#')
  "
}
```

### Drop Messages with Encoding Issues

If you prefer to drop messages with encoding issues:

```ruby
if [message] =~ /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\xFF]/ {
  drop { }
}
```

### Log Original Binary Data in Hex Format

To preserve the original binary data in a more readable format:

```ruby
ruby {
  code => "
    message = event.get('message')
    if message.match?(/[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F-\\xFF]/)
      event.set('original_binary', message.bytes.map { |b| sprintf('%02X', b) }.join(' '))
    end
    message.force_encoding('ISO-8859-1').encode!('UTF-8', :invalid => :replace, :undef => :replace, :replace => '?')
  "
}
```

## Performance Considerations

The Ruby filter adds some processing overhead. For high-volume logs:

1. Consider using conditional processing to apply the filter only when needed:
   ```ruby
   if [message] =~ /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\xFF]/ {
     ruby {
       # encoding conversion code
     }
   }
   ```

2. Monitor Logstash performance and adjust JVM memory settings if needed

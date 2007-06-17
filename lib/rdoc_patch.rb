require 'rdoc/usage'

#due to a bug in rdoc, RDoc.usage won't work correctly when run from a gem executable
# see http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/211297
# Display usage from the given file

def RDoc.usage_from_file(input_file, *args)
        comment = File.open(input_file) do |file|
                RDoc.find_comment(file)
        end
        comment = comment.gsub(/^\s*#/, '')

        markup = SM::SimpleMarkup.new
        flow_convertor = SM::ToFlow.new
    
        flow = markup.convert(comment, flow_convertor)

        format = "plain"

        unless args.empty?
                flow = extract_sections(flow, args)
        end

        options = RI::Options.instance
        if args = ENV["RI"]
                options.parse(args.split)
        end
        formatter = options.formatter.new(options, "")
        formatter.display_flow(flow)
        exit
end


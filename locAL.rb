# Penalties are hardcoded as match = 1, mismatch = -3, go/ge = -2 each
# Invoked without command line arguments as "ruby locAL.rb"


class Matrix # ruby matrices are immutable, so must create own class

  def initialize(rows, columns)
    @mutable_matrix = Array.new(rows)

    (0..rows-1).each do |row|
      @mutable_matrix[row] = Array.new(columns, 0)
    end
  end

  def [](row, column)
    return @mutable_matrix[row][column]
  end

  def []=(row, column, value)
    @mutable_matrix[row][column] = value
  end

  def debug
    puts @mutable_matrix.to_a.map(&:inspect)
  end
end


class LocalAlignment

  # set some class variables, create matrices
  def initialize(first_string, second_string)

    @height = first_string.length + 1
    @width = second_string.length + 1
    @matrix = Matrix.new(@height, @width) # scoring matrix
    @d_matrix = Matrix.new(@height, @width) # deletion matrix
    @i_matrix = Matrix.new(@height, @width) # insertion matrix
    @traceback_matrix = Matrix.new(@height, @width)  # traceback amtrix

    @first_string = first_string
    @second_string = second_string
    @first_sequence = first_string.unpack("U*") # for match comparison
    @second_sequence = second_string.unpack("U*")

  end

  # populates matrices by calling compute on each cell
  def fill_matrix!

    @max_cell = -1 # value at max_cell
    @max_cell_row = 0 # row of max_cell
    @max_cell_column = 0 # column of max_cell

    (1..@height-1).each do |row|
      (1..@width-1).each do |column|
        compute(row, column)
      end
    end

  end

  def compute(row, column) # fills in four matrices

    if(@first_sequence[row-1] == @second_sequence[column-1])
      match = 1
    else
      match = -3
    end

    # max match
    m = match + [
      @matrix[row-1, column-1],
      @d_matrix[row-1, column-1],
      @i_matrix[row-1, column-1],
    ].max

    # max deletion
    d = [
      -2 + @d_matrix[row, column-1],
      -2 + -2 + @matrix[row, column-1],
      -2 + -2 + @i_matrix[row, column-1],
    ].max

    # max insertion
    i = [
      -2 + @i_matrix[row-1, column],
      -2 + -2 + @matrix[row-1, column],
      -2 + -2 + @d_matrix[row-1, column],
    ].max

    # max score
    score = [m, d, i, 0].max
    
    @matrix[row, column] = score
    # no negative cells
    @d_matrix[row, column] = d < 0 ? 0 : d 
    @i_matrix[row, column] = i < 0 ? 0 : i


    # fill out trace back matrix with arbitrary (0...3)
    if score == m
      @traceback_matrix[row, column] = 1 # match/mismatch
    elsif score == d
      @traceback_matrix[row, column] = 2 # deletion
    elsif score == i
      @traceback_matrix[row, column] = 3 # insertion
    elsif score == 0
      @traceback_matrix[row, column] = 0
    end

    # reset greatest score cell
    if score >= @max_cell
      @max_cell = score
      @max_cell_row = row
      @max_cell_column = column
    end
  end

  def debug
    # puts "Match Matrix"
    # @matrix.debug
    # puts "Deletion Matrix"
    # @d_matrix.debug
    # puts "Insertion Matrix"
    # @i_matrix.debug
    # puts "Traceback Matrix"
    # @traceback_matrix.debug
    puts "score with affine gap pentalty is #{@max_cell}"
    # puts @max_cell_row
    # puts @max_cell_column
  end

  # traverse trace back matrix
  def align
    i = @max_cell_row
    j = @max_cell_column
    @first_result = "" 
    @second_result = "" 
    gaps_in_first = 0 # count of gaps in each sequence
    gaps_in_second = 0

    while true

      # end local alignment at 0 cell
      if @traceback_matrix[i, j] == 0
        break
      end

      # match/mismatch
      if @traceback_matrix[i, j] == 1
        @first_result << @first_string[i-1]
        @second_result << @second_string[j-1]
        i -= 1
        j -= 1
      end

      # deletion -> gap in S1
      if @traceback_matrix[i, j] == 2
        @first_result << "-"
        @second_result << @second_string[j-1]
        j -= 1
        gaps_in_first += 1
      end

      # insertion -> gap in S2
      if @traceback_matrix[i, j] == 3
        @first_result << @first_string[i-1]
        @second_result << "-"
        i -= 1
        gaps_in_second += 1
      end

    end
    # set variables to make writing to file prettier
    set_variables(gaps_in_first, gaps_in_second)
  end


  def set_variables(gaps_in_first, gaps_in_second)
    @start_first = @max_cell_row + gaps_in_first - @first_result.length
    @start_second = @max_cell_column + gaps_in_second - @second_result.length
    @central_alignment = "" # series of "|" and " "
  end

  # this method deals with formatting central sequence and formatting to file
  def write

    # reverse alignments
    @first_result.reverse!
    @second_result.reverse!

    # Create middle section for matches/mismatches
    index = 0
    @first_result.length.times do
      if @first_result[index] == @second_result[index]
        @central_alignment << "|"
      else
        @central_alignment << " "
      end
      index += 1
    end

    offset = @start_first > @start_second ? @start_first.to_s.length : @start_second.to_s.length
    border = ""

    (offset+1).times do # lines up center with alignments
      border << "="
    end

    # formats beginning and end of sequence output
    @first_result.insert(0, @start_first.to_s << "=")
    @first_result << "=" << @max_cell_row.to_s
    @second_result.insert(0, "" << @start_second.to_s << "=")
    @second_result << "=" << @max_cell_column.to_s
    @central_alignment.insert(0, border)
    @central_alignment << border

    # separate sequences and center into at most chunks of at most 60
    first_chunks = @first_result.scan(/.{1,60}/)
    central_chunks = @central_alignment.scan(/.{1,60}/)
    second_chunks = @second_result.scan(/.{1,60}/)

    length = first_chunks.length

    File.open("result.txt", 'w') {|file| 
      i = 0
      length.times do
        file.puts first_chunks[i]
        file.puts central_chunks[i]
        file.puts second_chunks[i]
        file.puts
        i += 1
      end
    }

  end
end


# Read from file, hardcoded
first = ""
second = ""

File.open("human.txt", "r").each_with_index do |line, index|
  if index != 0
    first << line
  end
end

File.open("mouse.txt", "r").each_with_index do |line, index|
  if index != 0
    second << line
  end
end

first.gsub!(/\n/,"")
second.gsub!(/\n/,"")

puts "File names and parameters are hardcoded as follows:"
puts "Files = human.txt and mouse.txt"
puts "Match = 1, Mismatch = -3, Gap Open = -2, Gap Extend = -2"
puts "Writes to file result.txt"
puts "Takes 5-10 minutes"

# Create alignment object, retrieve score, perform alignment
local = LocalAlignment.new(first, second)
local.fill_matrix!
local.debug
local.align
local.write





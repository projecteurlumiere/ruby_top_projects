require 'yaml'

module DisplayHangman
  # Hangmanpics are taken from: 
  # chirhorton at https://gist.github.com/chrishorton/8510732aa9a80a03c829b09f12e20d9c
  # in contrast with python, triple quotes are unsupported in Ruby - use ' or "

  HANGMANPICS = ['
    +---+
    |   |
        |
        |
        |
        |
  =========', '
    +---+
    |   |
    O   |
        |
        |
        |
  =========', '
    +---+
    |   |
    O   |
    |   |
        |
        |
  =========', '
    +---+
    |   |
    O   |
   /|   |
        |
        |
  =========', '
    +---+
    |   |
    O   |
   /|\  |
        |
        |
  =========', '
    +---+
    |   |
    O   |
   /|\  |
   /    |
        |
  =========', '
    +---+
    |   |
    O   |
   /|\  |
   / \  |
        |
  =========']

  def display_hangman(errors)
    puts "\n\n#{HANGMANPICS[errors]}\nyou have #{6 - errors} attempts\n"
  end
end

module CaesarEncrypt
  def hide_codeword(game_info)
      @encrypted_codeword = encrypt(game_info[:codeword])
      game_info[:codeword] = @encrypted_codeword[:ciphered_string]
      game_info[:shift] = @encrypted_codeword[:shift]
      game_info
  end

  def reveal_codeword(loaded_hash)
    loaded_hash[:codeword] = decrypt(loaded_hash[:codeword], loaded_hash[:shift])
    loaded_hash.delete(:shift)
    loaded_hash
  end

  private
  def encrypt(string)
    random_shift = Random.rand(1...25)
    {
      ciphered_string: caesar_cipher(string, random_shift),
      shift: random_shift
    }
  end

  def decrypt(string, shift)
    caesar_cipher(string, shift * -1)
  end

  private
  def caesar_cipher(string, shift)
    shift = shift - ((shift / 26) * 26) # division returns not rounded integer
    ciphered = string.split("").reduce("") do | newstring, symbol |
      if (symbol.ord >= 97 && symbol.ord <= 122) 
        define_ascii(newstring, symbol, shift, 97, 122)
      elsif (symbol.ord >= 65 && symbol.ord <= 90)
        define_ascii(newstring, symbol, shift, 65, 90)
      else 
        newstring << symbol
      end
    end
    ciphered
  end
  
  def define_ascii(newstring, symbol, shift, min_ascii, max_ascii)
    if (symbol.ord + shift) < min_ascii
      newstring << (symbol.ord + shift + 26).chr
    elsif (symbol.ord + shift) > max_ascii
      newstring << (symbol.ord + shift - 26).chr 
    else
      newstring << (symbol.ord + shift).chr
    end
  end
end

class Game
  include DisplayHangman

  def initialize(player_class)
    @player = player_class.new(self)
    @dictionary = File.read("google-10000-english-no-swears.txt").split
    @saveload = SaveLoad.new(self, @player)
    start_game
  end

  def start_game
    if File.exist?("save.yml")
      load_previous_game
    else
      generate_new_game
    end

    play_rounds

    finish_round

    offer_replay
  end

  def get_game_information
    {
      codeword: @codeword,
      guessed_letters: @guessed_letters,
      errors: @errors,
      used_letters_and_phrases: @used_letters_and_phrases
    }
  end

  def get_used_letters_and_phrases
    @used_letters_and_phrases
  end

  private

  def load_previous_game
    puts "\nloading previous game...\n"
    loaded_game = @saveload.load_game
    @codeword = loaded_game[:codeword]
    @guessed_letters = loaded_game[:guessed_letters]
    @errors = loaded_game[:errors]
    @used_letters_and_phrases = loaded_game[:used_letters_and_phrases]
  end

  def generate_new_game
    @codeword = get_random_word
    @guessed_letters = Array.new(@codeword.length, '?')
    @errors = 0
    @used_letters_and_phrases = Array.new(0)
  end

  def play_rounds
    until gameover? do
      display_hangman(@errors)

      puts "\n#{@guessed_letters.join(" ")}\n"
      @input = @player.get_input
      @used_letters_and_phrases << @input.upcase
      @previous_guessed_letters = Array.new(@guessed_letters)
      @guessed_letters = process_input(@codeword, @input, @guessed_letters)

      if @guessed_letters == @previous_guessed_letters && @input != @codeword
        puts "\n\n\n\n\nyou were wrong about #{@input}...\n"
        @errors += 1
      else
        puts "\n\n\n\n\n\n"
      end

      @saveload.save_game
    end
  end

  def finish_round
    if player_won?
      puts "\nyay, you won!\n"
    else
      display_hangman(@errors)
      puts "\nyou lost...\n"
    end

    puts "\nthe word was #{@codeword.upcase}"
    @saveload.delete_save
  end

  def offer_replay
    puts "\nanother one? yes or no\n"

    if another_one?
      start_game
    else
      puts "\nbye!\n"
    end
  end

  def another_one?
    @response = gets.chomp.downcase
    until @response == 'yes' || @response == 'no' || @response == 'y' || @response == 'n'
      puts "come again"
      another_one?
    end
    if @response== 'yes' || @response == 'y'
      true
    elsif @response == 'no' || @response == 'n'
      false
    end
  end

  def get_random_word
    @random_word = @dictionary.sample(1)[0]
    @random_word = @dictionary.sample(1)[0] until @random_word.length.between?(5, 12)
    @random_word
  end

  def process_input(codeword, input, guessed_letters)
    codeword.split("").each_with_index do |letter, index|
      if letter == input
        guessed_letters[index] = letter
      end
    end
    guessed_letters
  end

  def gameover?
    @guessed_letters == @codeword || @input == @codeword || @errors == 6 
  end

  def player_won?
    @guessed_letters == @codeword || @input == @codeword
  end
end

class Player
  def initialize(game_class)
    @game = game_class
  end

  def get_input
    @input = nil

    until (!@input.nil? &&
      !@input.strip.empty?) &&
      ((@input.upcase.strip.ord.between?(65, 90) || @input.strip.length > 1) &&
      !@game.get_used_letters_and_phrases.include?(@input.strip.upcase))
      puts "\nawaiting correct input: letter or entire word\n\nPrevious guesses are: #{@game.get_used_letters_and_phrases.join ", "}\n\n"
      @input = gets.chomp.to_s.strip
    end
    @input
  end

  def load_used_letters_and_phrases(input)
    @used_letters_and_phrases = input
  end
end

class SaveLoad
  include CaesarEncrypt
  
  def initialize(game_class, player_class)
    @game = game_class
    @player = player_class
  end

  def save_game
    @game_info = @game.get_game_information
    @game_info = hide_codeword(@game_info)

    File.open('save.yml', 'w') do |file|
      file.write @game_info.to_yaml
    end
  end

  def load_game
    File.open('save.yml', 'r') do |file|
      @loaded_hash = YAML.load_file(file)
    end
    @loaded_hash = reveal_codeword(@loaded_hash)
    @loaded_hash
  end

  def delete_save
    File.delete('save.yml')
  end
end

Game.new(Player)

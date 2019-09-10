class MatchChannel < ApplicationCable::Channel
  def subscribed
    raise "user_idがないってどういうことよ" unless user_id = params[:user_id]
    raise "player_countがないってどういうこと" unless player_count = params[:player_count]
    raise "categoryがないってどういうこと" unless category = params[:category].to_i

    stream_from user_room(user_id) #各自用

    room_queue = RoomQueue.new(room_key: match_room_name)

    # OPTIMIZE: 対戦サーバーが取り出してマッチングさせてもいいかも。
    return if room_queue.push(user_id) < player_count
    return unless players = room_queue.get_players(player_count)

    # 部屋の成立 ここらへんYAGNIな気も
    room = Room.new(
      players: players,
      level: params[:level],
      category: category
    ).save

    players.each do |player|
      start_match(player, players.reject{|e|e==player}, room.id)
      User.new(id: player, problems: []).save
    end
  end

  def unsubscribed
    RoomQueue.new(room_key: match_room_name).disable_user(params[:user_id])
  end 

  private
  # DEBUG用: 自分以外のuser-idを教えると不正が行えてしまう
  def start_match(owner, opponent,room_id)
    ActionCable.server.broadcast user_room(owner), type: "moveRoom", message: "対戦相手が見つかりました#{opponent}", room_id: room_id
  end
  
  def user_room(user_id)
    "match#{user_id}"
  end

  def match_room_name
    "#{params[:level]}-#{params[:category]}-#{params[:player_count]}"
  end
end

import 'package:flutter/cupertino.dart';

import '../../model/api_models/all_categories/all_category_song_model.dart';
import '../../model/api_models/music_style_models/music_style_model.dart';

class MusicStyleProvider extends ChangeNotifier{
  List<MusicStyleModel> musicStyleList=[];
  List<CategoriesSongModel> songsInCategoryList=[];

  updateMusicStyleList(List<MusicStyleModel> list){
   musicStyleList=list;
   notifyListeners();
  }

  updateSongsInCategoryList(List<CategoriesSongModel> songs){
    songsInCategoryList.clear();
    songsInCategoryList=songs;
    notifyListeners();
  }



}
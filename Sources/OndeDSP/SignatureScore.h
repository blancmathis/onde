/* Four authored scores, not randomized playlists. Included only by OndeDSP.c.
   A voice count is not a cognitive score; tempos are artistic choices.
   Stable rhythmic landmarks and common-tone voice leading are maintained. */
static const int signatureChords[4][4][5]={
 /* Sillage: F minor / shared pedal, soft modal colour. */
 {{53,60,63,67,72},{53,60,65,68,72},{53,58,65,68,72},{53,60,63,68,72}},
 /* Filigrane: F major, suspended inner voicings, low tessitura. */
 {{53,57,60,65,67},{53,58,60,65,67},{53,57,62,65,69},{53,57,60,65,69}},
 /* Confluence: fifths, then one inner voice moves; no cinematic cadence. */
 {{53,60,65,67,72},{53,60,64,67,72},{53,58,65,67,72},{53,60,65,69,72}},
 /* Sanctuaire: vowel ensemble, no syllabic/melodic lead. */
 {{53,60,65,69,72},{53,60,65,67,72},{53,58,65,69,72},{53,60,64,69,72}}
};
static int signature_id(OndeDSP*s){return s->score;}
static const int *signature_chord(OndeDSP*s){
 int id=s->score;uint64_t bar=s->bars-s->scoreStartBar;
 int hold=id==3?24:16;s->field=(int)((bar/hold)%4);
 return signatureChords[id-1][s->field];
}
static void signature_score(OndeDSP*s,int k){
 int id=s->score;const int *ch=signature_chord(s);
 uint64_t bar=s->bars-s->scoreStartBar;double beat=60/s->bpm;
 float detail=s->detail;float density=s->now[ONDE_DENSITY];
 /* The microphrase repeats. Long changes are one common-tone chord at a time. */
 if(id==1){
  static const int slots[4]={0,6,10,14},degrees[8]={0,2,1,2,0,3,1,2};
  static const float velocity[4]={1,.73f,.86f,.69f};
  for(int i=0;i<4;i++)if(k==slots[i]){
   int idx=(int)(bar%2)*4+i;
   note(s,ch[degrees[idx]]+(i==1?12:0),1,(.062f+.047f*density)*velocity[i]*detail,.43f+.07f*(i%2),0);
  }
  if(k==0 && bar%4==0)for(int i=0;i<4;i++)pad(s,ch[i],i<2?.031f:.019f,0);
  /* One composed low rim-like tone, not noisy hats or a random fill. */
  if(k==4||k==12)note(s,65,1,.014f*detail,.5f,0);
 }else if(id==2){
  /* A left-hand anchor and a two-bar right-hand cell. No improvised rubato. */
  if(k==0)orc_note(s->orchestra,11,41,.34f,.48f,beat*7,s->seed);
  if(k==8)orc_note(s->orchestra,11,48,.23f,.49f,beat*6,s->seed);
  if(k==2||k==10 || ((k==6||k==14)&&density>.50f)){
   static const int notes[8]={1,2,4,2,1,2,3,2};
   int idx=((int)(bar%4)*2+(k>=8))%8;
   float level=(k==2?.38f:k==10?.32f:.16f)*detail;
   orc_note(s->orchestra,11,ch[notes[idx]],level,.54f,beat*6,s->seed);
  }
  if(k==0&&bar%4==0){
   orc_note_held(s->orchestra,2,41,.08f,.58f,beat*18,s->seed);
   orc_note_held(s->orchestra,1,ch[2],.065f,.45f,beat*18,s->seed);
  }
 }else if(id==3){
  /* Distinct desks enter at fixed offsets, then sustain across bar lines. */
  if(bar%4==0){
   if(k==0){orc_note_held(s->orchestra,2,41,.39f,.59f,beat*18,s->seed);orc_note_held(s->orchestra,2,48,.22f,.63f,beat*18,s->seed+1);}
   if(k==2){orc_note_held(s->orchestra,1,ch[1],.29f,.47f,beat*18,s->seed);orc_note_held(s->orchestra,1,ch[2],.19f,.52f,beat*18,s->seed+1);}
   if(k==4){orc_note_held(s->orchestra,0,ch[3],.24f,.28f,beat*18,s->seed);orc_note_held(s->orchestra,0,ch[4],.17f,.36f,beat*18,s->seed+1);}
   if(k==6){orc_note_held(s->orchestra,5,53,.25f,.63f,beat*18,s->seed);orc_note_held(s->orchestra,6,53,.15f,.5f,beat*18,s->seed);}
  }
  if(k%2==0&&detail>.005f){
   static const int low[8]={41,48,53,48,41,48,53,48};
   int i=k/2;float accent=(k%4==0?1.f:.73f);
   orc_note(s->orchestra,3,low[i],.25f*accent*detail,.59f,beat*.76,s->seed);
   if(k%4==0)orc_note(s->orchestra,4,ch[(i/2)%4+1],.095f*detail,.30f,beat*.8,s->seed);
  }
  if(k==0||k==8){orc_note(s->orchestra,9,k==0?41:48,(k==0?.26f:.16f)*detail,.52f,beat*2,s->seed);}
  if(k==6||k==14)orc_note(s->orchestra,8,ch[k==6?2:3],.10f*detail,.42f,beat*4,s->seed);
 }else if(id==4){
  if(k==0){int v[4]={ch[0],ch[1],ch[2],ch[3]};choir_chord(s->choir,v,beat*4);}
  /* The bass remains rhythmic while the vowels have no repeated syllabic attack. */
  if(bar%4==0&&k==0){
   orc_note_held(s->orchestra,2,41,.19f,.60f,beat*18,s->seed);
   orc_note_held(s->orchestra,1,ch[1],.11f,.46f,beat*18,s->seed);
  }
  if((k==2||k==10)&&density>.1f)orc_note(s->orchestra,8,ch[k==2?1:2],.14f*detail,.47f,beat*4,s->seed);
  if(k==0||k==8)orc_note(s->orchestra,10,36,.075f*detail,.50f,beat*2,s->seed);
 }
 s->signatureEvents++;
}

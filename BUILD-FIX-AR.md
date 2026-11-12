# إصلاح فشل البناء على GitHub Actions — النسخة 1.0.1

## الخطأ الذي ظهر لك

```
xcodebuild: error: The flag -scheme, -testProductsPath, or -xctestrun
is required when specifying -derivedDataPath.
```

## السبب

الأمر القديم كان يجمع بين `-target` و `-derivedDataPath`:

```bash
xcodebuild -project CentreAitigrine.xcodeproj \
  -target CentreAitigrine \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build        ← هذا الخيار لا يُقبل مع -target
```

قاعدة `xcodebuild`: الخيار `-derivedDataPath` يعمل **فقط** مع البناء عبر
`-scheme` (أو `-xctestrun`)، وليس مع `-target`. لذلك خرج الأمر برمز الخطأ 64.

## الحل المطبَّق في `.github/workflows/ios-build.yml` (v2)

1. **البناء الأساسي عبر الـ Scheme** (الصيغة الصحيحة):

```bash
xcodebuild \
  -project CentreAitigrine.xcodeproj \
  -scheme CentreAitigrine \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

2. **مسار بديل تلقائي**: إن فشل بناء الـ Scheme لأي سبب، يجرّب الـ workflow
   تلقائياً البناء عبر `-target` **بدون** `-derivedDataPath`، مع توجيه الناتج
   إلى `build/SYM` عبر `SYMROOT` (وهذا مسموح مع `-target`):

```bash
xcodebuild -project CentreAitigrine.xcodeproj \
  -target CentreAitigrine \
  -configuration Release \
  -sdk iphoneos \
  SYMROOT="$PWD/build/SYM" OBJROOT="$PWD/build/OBJ" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

3. **البحث المرن عن التطبيق**: خطوة تجميع الـ IPA تبحث عن
   `CentreAitigrine.app` أينما وُجد (`build` أو `DerivedData`) بدلاً من مسار ثابت.

4. **سجل بناء كـ Artifact**: في حال أي فشل مستقبلي ستجد Artifact باسم
   `build-log` يحتوي السجل الكامل للتشخيص الفوري.

## كيف تطبّق الإصلاح على GitHub (اختر طريقة واحدة)

### الطريقة الأسرع — تعديل مباشر من المتصفح

1. افتح مستودعك → الملف `.github/workflows/ios-build.yml`
2. اضغط أيقونة القلم ✏️ (Edit)
3. امسح كل المحتوى والصق محتوى الملف الجديد المرفق في هذه الحزمة
4. Commit changes
5. اذهب إلى تبويب **Actions** → **iOS Build** → **Run workflow** → **Run workflow**
6. بعد انتهاء البناء (أخضر) نزّل الـ Artifact: **CentreAitigrine-unsigned-ipa**

### الطريقة الثانية — رفع الحزمة كاملة

ارفع محتويات هذه الحزمة إلى المستودع (استبدال الملفات القديمة) ثم شغّل
**Actions → iOS Build → Run workflow**.

## بعد الحصول على IPA

تابع دليل Sideloadly المعتاد: نزّل `CentreAitigrine-unsigned.ipa` من الـ
Artifact، ثم في Sideloadly على Windows: اسحب الملف + سجّل Apple ID +
App-Specific Password → ابدأ التثبيت → على الآيفون:
الإعدادات → عام → إدارة VPN والجهاز → ثق بـ Apple Developer certificate.

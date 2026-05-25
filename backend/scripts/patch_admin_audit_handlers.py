import re
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent / "api" / "internal" / "handler" / "admin"

WRITE_HANDLERS = [
    "adminupdateuserhandler.go",
    "admincreatevipplanhandler.go",
    "adminupdatevipplanhandler.go",
    "admindeletevipplanhandler.go",
    "adminbootstrapvipplanshandler.go",
    "adminbootstrapachievementshandler.go",
    "admincreategifthandler.go",
    "adminupdategifthandler.go",
    "admindeletegifthandler.go",
    "adminbootstrapgiftshandler.go",
    "admindeleteposthandler.go",
    "admindeletecommenthandler.go",
    "admindeletegrouphandler.go",
    "adminbootstraplevelshandler.go",
    "adminupdatelevelconfighandler.go",
    "adminupdatecheckinrewardhandler.go",
    "adminupdateachievementhandler.go",
    "admincreateannouncementhandler.go",
    "adminupdateannouncementhandler.go",
    "admindeleteannouncementhandler.go",
    "adminpublishannouncementhandler.go",
    "adminbroadcastnotificationhandler.go",
    "adminsendnotificationhandler.go",
    "admindeleteaiagenthandler.go",
    "admindeletefollowhandler.go",
    "admincreateaccounthandler.go",
    "adminupdateaccounthandler.go",
    "admindeleteaccounthandler.go",
    "adminupsertmenuhandler.go",
    "admindeletemenuhandler.go",
    "adminbootstrapmenushandler.go",
    "adminupdateruntimeconfighandler.go",
    "admindeletemediaimagehandler.go",
    "admindeletememoryhandler.go",
]

READ_AUTH_HANDLERS = [
    "adminlistauditlogshandler.go",
    "admingetannouncementhandler.go",
    "admingetgrowthstatshandler.go",
    "admingetmemorystatshandler.go",
    "admingetruntimeconfighandler.go",
    "admingetschemacataloghandler.go",
    "admingetuserprofilehandler.go",
    "adminlistaccountshandler.go",
    "adminlistachievementshandler.go",
    "adminlistaiagentshandler.go",
    "adminlistannouncementshandler.go",
    "adminlistcheckinrewardshandler.go",
    "adminlistfollowshandler.go",
    "adminlistfriendrequestshandler.go",
    "adminlistlevelconfigshandler.go",
    "adminlistmediaimageshandler.go",
    "adminlistmemorieshandler.go",
    "adminlistmenushandler.go",
]


def patch_file(path: pathlib.Path) -> bool:
    text = path.read_text(encoding="utf-8")
    orig = text
    if "PrepareAdminContext" in text:
        return False

    text = re.sub(
        r"\n\t\tif _, br := common\.RequireAdminToken\(r\); br != nil \{\n\t\t\thttpx\.OkJsonCtx\(r\.Context\(\), w, &types\.[^\n]+\{BaseResp: \*br\}\)\n\t\t\treturn\n\t\t\}\n",
        "\n",
        text,
    )

    if "backend/api/internal/common" not in text:
        text = text.replace(
            '"net/http"\n\n',
            '"net/http"\n\n\t"backend/api/internal/common"\n',
        )

    needle = "return func(w http.ResponseWriter, r *http.Request) {\n"
    if needle in text:
        text = text.replace(
            needle,
            needle
            + "\t\tctx, ok := common.PrepareAdminContext(w, r)\n"
            + "\t\tif !ok {\n"
            + "\t\t\treturn\n"
            + "\t\t}\n",
            1,
        )

    text = text.replace("(r.Context(), svcCtx)", "(ctx, svcCtx)")

    if text != orig:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> None:
    for name in WRITE_HANDLERS + READ_AUTH_HANDLERS:
        path = ROOT / name
        if not path.exists():
            print("missing", name)
            continue
        if patch_file(path):
            print("patched", name)
        else:
            print("skip", name)


if __name__ == "__main__":
    main()
